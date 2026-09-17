"""Оркестрация импорта: Telegram → Yandex S3 → Supabase.

Однократный миграционный инструмент. На каждую публикацию создаётся строка
publications (+content_blocks, +publication_sections). Повторный запуск
пропускает уже импортированные сообщения по publications.telegram_message_id.
"""
from __future__ import annotations

import asyncio
import json
import logging
import mimetypes
import shutil
import tempfile
from pathlib import Path

from config import Settings
from media_storage import MediaStorage
from models import MediaType, ParsedMessage
from parser import (
    build_block_rows,
    decide_icon,
    decide_publication_type,
    derive_title,
    parse_group,
)
from supabase_client import SupabaseClient

logger = logging.getLogger("importer")

ERRORS_FILE = Path(__file__).resolve().parent / "errors.jsonl"


def group_albums(messages: list) -> list[list]:
    """Группирует сообщения в публикации.

    Сообщения альбома (несколько фото) идут подряд и имеют одинаковый
    grouped_id — объединяем их в одну публикацию.
    """
    groups: list[list] = []
    current_group_id: int | None = None
    current: list = []

    def flush() -> None:
        nonlocal current
        if current:
            groups.append(current)
            current = []

    for message in messages:
        grouped_id = message.grouped_id
        if grouped_id is not None:
            if grouped_id != current_group_id:
                flush()
                current_group_id = grouped_id
            current.append(message)
        else:
            flush()
            groups.append([message])
    flush()
    return groups


class Importer:
    def __init__(
        self,
        settings: Settings,
        telegram,
        dry_run: bool = False,
        section_slug: str | None = None,
    ) -> None:
        self.settings = settings
        self.telegram = telegram
        self.dry_run = dry_run
        self.section_slug = section_slug or settings.default_section_slug

        self._db: SupabaseClient | None = None
        self._storage: MediaStorage | None = None

        self.imported = 0
        self.skipped = 0
        self.errors: list[dict] = []
        self.would_import = 0  # только для dry-run

    # ----------------------------------------------------------
    # Ленивые клиенты (не создаются при --dry-run)
    # ----------------------------------------------------------

    def _ensure_db(self) -> SupabaseClient:
        if self._db is None:
            self._db = SupabaseClient(
                self.settings.supabase_url, self.settings.supabase_service_role_key
            )
        return self._db

    def _ensure_storage(self) -> MediaStorage:
        if self._storage is None:
            self._storage = MediaStorage(
                endpoint=self.settings.yandex_endpoint,
                region=self.settings.yandex_region,
                bucket=self.settings.yandex_bucket,
                access_key=self.settings.yandex_access_key,
                secret_key=self.settings.yandex_secret_key,
            )
        return self._storage

    # ----------------------------------------------------------
    # Запуск
    # ----------------------------------------------------------

    async def run(self, channel_spec: str, limit: int | None = None) -> None:
        logger.info("[INFO] Resolving channel %s", channel_spec)
        channel = await self.telegram.resolve_channel(channel_spec)

        logger.info("[INFO] Fetching messages (limit=%s)…", limit)
        messages = await self.telegram.fetch_messages(channel, limit=limit)
        logger.info("[INFO] Got %d messages, grouping publications…", len(messages))

        groups = group_albums(messages)
        logger.info("[INFO] Found %d publications", len(groups))

        section_id: str | None = None
        if not self.dry_run:
            section_id = await asyncio.to_thread(self._get_section_id)

        for group in groups:
            parsed = parse_group(group, channel_username=self.telegram.channel_username)
            await self._process(parsed, section_id)

        self._print_report()

    def _get_section_id(self) -> str:
        return self._ensure_db().get_section_id(self.section_slug)

    # ----------------------------------------------------------
    # Обработка одной публикации
    # ----------------------------------------------------------

    async def _process(self, parsed: ParsedMessage, section_id: str | None) -> None:
        if parsed is None:
            logger.warning("[WARN] Пустая группа сообщений — пропуск")
            self.skipped += 1
            return

        if parsed.skip_reason:
            logger.info("[SKIP] message %s: %s", parsed.message_id, parsed.skip_reason)
            self.skipped += 1
            return

        if not self.dry_run and await asyncio.to_thread(
            self._ensure_db().has_message, parsed.message_id
        ):
            logger.info("[SKIP] message %s уже импортировано", parsed.message_id)
            self.skipped += 1
            return

        if self.dry_run:
            self._print_dry_run(parsed)
            self.would_import += 1
            return

        await self._import_message(parsed, section_id)

    # ----------------------------------------------------------
    # Реальный импорт
    # ----------------------------------------------------------

    async def _import_message(self, parsed: ParsedMessage, section_id: str) -> None:
        db = self._ensure_db()
        storage = self._ensure_storage()

        temp_dir = tempfile.mkdtemp(prefix="tatislam_import_")
        try:
            publication_type = decide_publication_type(parsed)
            photo_publication = publication_type == "photo"

            # 1. Скачиваем медиа и загружаем в S3.
            key_by_item = {}
            for item in parsed.supported_media:
                logger.info(
                    "[INFO] message %s: download %s…", parsed.message_id, item.kind.value
                )
                local_path = await self.telegram.download_media(item.message, temp_dir)
                if local_path is None:
                    raise RuntimeError(
                        f"Не удалось скачать {item.kind.value} (msg {item.message_id})"
                    )
                data = local_path.read_bytes()
                extension = local_path.suffix or _extension_for(item)
                content_type = item.mime_type or mimetypes.guess_type(f"file{extension}")[0]

                logger.info(
                    "[INFO] message %s: upload %s to S3…", parsed.message_id, item.kind.value
                )
                key = await asyncio.to_thread(
                    storage.upload, data, item.folder, extension, content_type
                )
                key_by_item[item] = key

            for warning in parsed.warnings:
                logger.warning("[WARN] message %s: %s", parsed.message_id, warning)

            # 2. Создаём publications.
            photo_key = None
            if photo_publication:
                photo_key = next(iter(key_by_item.values()))

            row = _build_publication_row(
                parsed,
                section_id=section_id,
                publication_type=publication_type,
                photo_key=photo_key,
                status=self.settings.publication_status,
            )
            created = await asyncio.to_thread(db.create_publication, row)
            publication_id = created["id"]

            try:
                # 3. content_blocks.
                block_rows = build_block_rows(
                    parsed,
                    key_for=lambda item: key_by_item[item],
                    public_url_for=storage.public_url,
                    photo_publication=photo_publication,
                )
                for block in block_rows:
                    block["publication_id"] = publication_id
                await asyncio.to_thread(db.insert_content_blocks, block_rows)

                # 4. Связь с основной секцией (нужна для отображения в приложении).
                await asyncio.to_thread(db.add_section_membership, publication_id, section_id)
            except Exception:
                # Откат только что созданной строки publications — FK каскадом
                # удалят content_blocks и publication_sections.
                await asyncio.to_thread(db.delete_publication, publication_id)
                raise

            # 5. Push-уведомление о новой публикации (ТОЧКА ИНТЕГРАЦИИ).
            # Edge Function сама идемпотентна (claim по publication_id),
            # поэтому даже при повторном запуске импортёра push уйдёт только
            # один раз. Ошибка рассылки НЕ откатывает импорт.
            if self.settings.push_notifications_enabled:
                try:
                    await asyncio.to_thread(
                        db.notify_new_publication, publication_id
                    )
                except Exception as notify_exc:
                    logger.warning(
                        "[WARN] message %s: push notify failed: %s",
                        parsed.message_id,
                        notify_exc,
                    )

            logger.info("[OK] Imported message %s", parsed.message_id)
            self.imported += 1
        except Exception as exc:
            logger.error("[ERROR] Failed to import message %s: %s", parsed.message_id, exc)
            try:
                await asyncio.to_thread(db.delete_by_telegram_id, parsed.message_id)
            except Exception:
                pass
            self.errors.append(
                {
                    "message_id": parsed.message_id,
                    "source_url": parsed.source_url,
                    "error": str(exc),
                }
            )
            self._append_error(parsed.message_id, parsed.source_url, str(exc))
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

    # ----------------------------------------------------------
    # Dry-run и отчёт
    # ----------------------------------------------------------

    def _print_dry_run(self, parsed: ParsedMessage) -> None:
        media = parsed.supported_media
        by_kind = {MediaType.IMAGE: 0, MediaType.AUDIO: 0, MediaType.VIDEO: 0}
        for item in media:
            by_kind[item.kind] += 1
        text = parsed.text or ""
        print(
            f"Message {parsed.message_id}\n"
            f"  type: {decide_publication_type(parsed)}\n"
            f"  text: {'yes' if text.strip() else 'no'} ({len(text)} chars)\n"
            f"  images: {by_kind[MediaType.IMAGE]}\n"
            f"  audio: {'yes' if by_kind[MediaType.AUDIO] else 'no'}\n"
            f"  video: {'yes' if by_kind[MediaType.VIDEO] else 'no'}"
            f"{f' (links: {len(parsed.video_links)})' if parsed.video_links else ''}\n"
            f"  action: IMPORT"
        )
        for warning in parsed.warnings:
            print(f"  warning: {warning}")

    def _print_report(self) -> None:
        print("\n" + "=" * 40)
        print(f"Imported: {self.imported}")
        print(f"Skipped: {self.skipped}")
        print(f"Errors: {len(self.errors)}")
        if self.dry_run:
            print(f"К импорту (dry-run): {self.would_import}")
            print("Режим dry-run: ничего не загружено и не записано в БД.")
        if self.errors:
            print("\nErrors:")
            for error in self.errors:
                print(f"  - {error}")
            print(f"\nОшибки также сохранены в {ERRORS_FILE.name}")

    def _append_error(self, message_id: int, source_url: str | None, error: str) -> None:
        record = {"message_id": message_id, "source_url": source_url, "error": error}
        with open(ERRORS_FILE, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# Вспомогательные функции
# ---------------------------------------------------------------------------

def _extension_for(item) -> str:
    if item.kind is MediaType.IMAGE:
        return ".jpg"
    if item.kind is MediaType.VIDEO:
        return ".mp4"
    return ".mp3"


def _build_publication_row(
    parsed: ParsedMessage,
    *,
    section_id: str,
    publication_type: str,
    photo_key: str | None,
    status: str,
) -> dict:
    row = {
        "title": derive_title(parsed.text, parsed.message_id),
        "type": publication_type,
        "status": status,
        "published_at": parsed.date.isoformat(),
        "primary_section_id": section_id,
        "has_additional_sections": False,
        "telegram_message_id": parsed.message_id,
    }
    if parsed.source_url:
        row["source_url"] = parsed.source_url
    icon = decide_icon(publication_type, parsed)
    if icon:
        row["icon"] = icon
    if photo_key:
        row["photo_path"] = photo_key
    return row