"""Чтение истории канала из официального экспорта Telegram Desktop.

Пригодится, если нет возможности получить Telegram API credentials
(my.telegram.org) — экспорт делается из приложения Telegram Desktop
(«Export chat history», формат JSON) и не требует никаких API-ключей.

Формат входного файла — result.json:
    {
      "name": "Канал",
      "type": "public_channel",
      "messages": [
        {"id": 100, "type": "message", "date": "...", "date_unixtime": "...",
         "text": "текст или массив сегментов",
         "media_type": "photo", "photo": "photos/photo_1.jpg",
         "grouped_id": "..."}
      ]
    }

Медиа-файлы уже лежат рядом с result.json (photos/, video_files/,
audio_files/, ...), поэтому скачивать ничего не нужно — импортёр сразу
загрузит их в Yandex Object Storage.
"""
from __future__ import annotations

import json
import mimetypes
from datetime import datetime, timezone
from pathlib import Path

from models import MediaItem, MediaType, ParsedMessage
from parser import classify_video_links

# media_type из экспорта → MediaType
_KNOWN_MEDIA_TYPES = {
    "photo": MediaType.IMAGE,
    "video_message": MediaType.VIDEO,
    "round_video_message": MediaType.VIDEO,
    "video_file": MediaType.VIDEO,
    "animation": MediaType.VIDEO,
    "voice_message": MediaType.AUDIO,
    "audio_file": MediaType.AUDIO,
}

# Расширение файла → MediaType (fallback для документов/непонятных media_type)
_EXT_KINDS = {
    ".jpg": MediaType.IMAGE,
    ".jpeg": MediaType.IMAGE,
    ".png": MediaType.IMAGE,
    ".mp3": MediaType.AUDIO,
    ".ogg": MediaType.AUDIO,
    ".opus": MediaType.AUDIO,
    ".m4a": MediaType.AUDIO,
    ".wav": MediaType.AUDIO,
    ".aac": MediaType.AUDIO,
    ".mp4": MediaType.VIDEO,
    ".mov": MediaType.VIDEO,
    ".mkv": MediaType.VIDEO,
    ".webm": MediaType.VIDEO,
    ".avi": MediaType.VIDEO,
    ".mpeg": MediaType.VIDEO,
    ".gif": MediaType.VIDEO,
}


class ExportFormatError(RuntimeError):
    """Файл экспорта повреждён или имеет неожиданный формат."""


def normalize_channel_username(raw: str | None) -> str | None:
    """Возвращает username канала для ссылок https://t.me/<username>/<id>.

    На вход допустимы: 'name', '@name', 'https://t.me/name', а также число-id
    или private-приглашение ('+...') — в этих случаях username отсутствует,
    вернётся None.
    """
    if not raw:
        return None
    value = str(raw).strip()
    if value.startswith("https://t.me/"):
        value = value[len("https://t.me/"):]
    elif value.startswith("t.me/"):
        value = value[5:]
    # Берём только первую часть пути (сам username), игнорируя хвосты вида
    # /<message_id> или ?start=...
    value = value.split("?")[0].split("/")[0].lstrip("@")
    if not value or value.isdigit() or value.startswith("+"):
        return None
    return value


def load_export(path: str | Path) -> dict:
    """Загружает result.json и возвращает верхний объект экспорта."""
    export_file = Path(path)
    if not export_file.is_file():
        raise ExportFormatError(f"Файл экспорта не найден: {export_file}")
    try:
        with open(export_file, encoding="utf-8") as handle:
            data = json.load(handle)
    except json.JSONDecodeError as exc:
        raise ExportFormatError(f"Не удалось прочитать JSON экспорта: {exc}") from exc
    if not isinstance(data, dict) or "messages" not in data:
        raise ExportFormatError("В файле нет поля 'messages' — это не экспорт истории?")
    return data


def iter_publications(
    data: dict,
    export_dir: str | Path,
    channel_username: str | None = None,
) -> list[ParsedMessage]:
    """Возвращает публикации экспорта (одна = одно сообщение или альбом).

    Альбомы (несколько фото с общим grouped_id) объединяются в одну
    публикацию — так же, как в режиме Telegram API.
    """
    export_path = Path(export_dir)
    records = sorted(
        (m for m in data.get("messages", []) if isinstance(m, dict)),
        key=lambda m: int(m.get("id") or 0),
    )

    groups: list[list[dict]] = []
    current: list[dict] = []
    current_group_id = None

    def flush() -> None:
        nonlocal current
        if current:
            groups.append(current)
            current = []

    for record in records:
        grouped_id = record.get("grouped_id")
        if grouped_id is None:
            flush()
            groups.append([record])
        else:
            if grouped_id != current_group_id:
                flush()
                current_group_id = grouped_id
            current.append(record)
    flush()

    # В этом формате экспорта нет grouped_id: Telegram-альбомы выглядят как
    # несколько подряд идущих сообщений с фото. Без склейки каждый снимок стал
    # бы отдельной публикацией.
    merged_groups: list[list[dict]] = []
    pending: list[dict] = []

    def flush_pending() -> None:
        nonlocal pending
        if not pending:
            return
        merged_groups.extend(_split_photo_run(pending))
        pending = []

    for group in groups:
        # Склеиваем только одиночные фото-сообщения; настоящие группы по
        # grouped_id (старые форматы экспорта) уже собраны выше.
        if len(group) == 1 and group[0].get("photo") and "File not included" not in str(group[0]["photo"]):
            pending.append(group[0])
        else:
            flush_pending()
            merged_groups.append(group)
    flush_pending()

    return [_group_to_parsed(group, export_path, channel_username) for group in merged_groups]


def _group_to_parsed(
    records: list[dict],
    export_path: Path,
    channel_username: str | None,
) -> ParsedMessage:
    records = sorted(records, key=lambda r: int(r.get("id") or 0))
    representative_id = int(records[0]["id"])

    if any(r.get("type") == "service" for r in records):
        return ParsedMessage(
            message_id=representative_id,
            messages=records,
            date=_parse_date(records[0]),
            text=None,
            skip_reason="служебное сообщение (service)",
        )

    text = _join_text(records)
    media, warnings = _parse_media(records, export_path)
    video_links = classify_video_links(text or "")

    supported_media = [m for m in media if m.kind is not MediaType.UNSUPPORTED]

    if not text and not video_links and not supported_media:
        why = "; ".join(warnings) if warnings else "пустое сообщение / неизвестный медиа"
        return ParsedMessage(
            message_id=representative_id,
            messages=records,
            date=_parse_date(records[0]),
            text=None,
            media=media,
            video_links=video_links,
            skip_reason=f"нет импортируемого содержимого ({why})",
            warnings=warnings,
        )

    source_url = (
        f"https://t.me/{channel_username}/{representative_id}" if channel_username else None
    )
    return ParsedMessage(
        message_id=representative_id,
        messages=records,
        date=_parse_date(records[0]),
        text=text,
        media=media,
        video_links=video_links,
        warnings=warnings,
        source_url=source_url,
    )


def _parse_date(record: dict) -> datetime:
    """Дата публикации: предпочтительно date_unixtime (это UTC)."""
    unixtime = record.get("date_unixtime")
    if unixtime is not None:
        try:
            return datetime.fromtimestamp(int(unixtime), tz=timezone.utc)
        except (ValueError, TypeError):
            pass
    raw = record.get("date") or ""
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    except ValueError:
        return datetime.now(timezone.utc)


def _segment_to_text(segment) -> str:
    """Сегмент text[] из экспорта → строка.

    У текстовых ссылок (text_link) сам URL лежит в `href`, а `text` — лишь
    подпись. Подклеиваем href, чтобы ссылки (например, youtube/rutube) не терялись.
    """
    if isinstance(segment, dict):
        text = str(segment.get("text", "") or "")
        href = segment.get("href")
        if href and str(href) not in text:
            return f"{text}\n{href}" if text.strip() else str(href)
        return text
    return str(segment)


def _record_text(record: dict) -> str:
    """Текст сообщения: строка или список сегментов."""
    value = record.get("text")
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "".join(_segment_to_text(segment) for segment in value)
    return ""


def _split_photo_run(run: list[dict]) -> list[list[dict]]:
    """Делит пробег подряд идущих фото на чанки-кандидаты в альбомы.

    В телеграм-альбоме подпись может быть только у последнего снимка, поэтому
    чанк — это последовательность фото, где текст есть максимум у последнего.
    Фото с собственной подписью, после которого идёт ещё фото, начинает новый
    чанк (это отдельный пост). Чанк из одного сообщения остаётся одиночной
    публикацией.
    """
    chunks: list[list[dict]] = []
    current: list[dict] = []
    has_text = False

    for record in run:
        if has_text:
            chunks.append(current)
            current = []
            has_text = False
        current.append(record)
        if _record_text(record).strip():
            has_text = True
    if current:
        chunks.append(current)
    return chunks


def _join_text(records: list[dict]) -> str | None:
    """Склеивает текст группы (в экспорте text — строка или массив сегментов)."""
    chunks: list[str] = []
    for record in records:
        piece = _record_text(record).strip()
        if piece and piece not in chunks:
            chunks.append(piece)
    return "\n\n".join(chunks) if chunks else None


def _parse_media(records: list[dict], export_path: Path) -> tuple[list[MediaItem], list[str]]:
    media: list[MediaItem] = []
    warnings: list[str] = []

    for record in records:
        media_type = record.get("media_type")
        path_field = record.get("photo") or record.get("file")
        message_id = int(record.get("id") or 0)

        kind = _export_kind(media_type, path_field)
        if kind is None:
            continue  # медиа нет

        if kind is MediaType.UNSUPPORTED:
            warnings.append(
                f"сообщение {message_id}: media_type={media_type!r}, файл={path_field!r}"
            )
            media.append(
                MediaItem(
                    kind=kind,
                    message_id=message_id,
                    warning="неподдерживаемый тип медиа в экспорте",
                    file_name=Path(path_field).name if path_field else None,
                )
            )
            continue

        # Поддерживаемое медиа: проверяем, что файл реально лежит рядом с JSON.
        path = None
        if path_field:
            candidate = export_path / path_field
            if candidate.is_file():
                path = str(candidate.resolve())
        if path is None:
            warnings.append(f"сообщение {message_id}: файл не найден ({path_field!r})")
            media.append(
                MediaItem(
                    kind=MediaType.UNSUPPORTED,
                    message_id=message_id,
                    warning=f"файл не найден: {path_field}",
                )
            )
            continue

        media.append(
            MediaItem(
                kind=kind,
                message_id=message_id,
                file_name=Path(path_field).name,
                mime_type=mimetypes.guess_type(path_field)[0],
                local_path=path,
            )
        )
    return media, warnings


def _export_kind(media_type, path_field) -> MediaType | None:
    """media_type из экспорта → MediaType.

    None — медиа нет; UNSUPPORTED — медиа есть, но использовать нельзя
    (стикер, файл не был скачан в экспорт); FILE — обычный файл (pdf и т.п.).
    """
    if media_type is None and not path_field:
        return None

    if media_type == "sticker":
        return MediaType.UNSUPPORTED

    if path_field and "File not included" in str(path_field):
        return MediaType.UNSUPPORTED

    if media_type in _KNOWN_MEDIA_TYPES:
        return _KNOWN_MEDIA_TYPES[media_type]

    # Документы произвольного состава: определяем по расширению файла.
    if path_field:
        extension = Path(path_field).suffix.lower()
        if extension in _EXT_KINDS:
            return _EXT_KINDS[extension]

    # Всё остальное (pdf, docx, pptx, zip и т.п.) — обычный файл.
    return MediaType.FILE