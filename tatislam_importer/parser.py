"""Анализ Telegram-сообщений: распознавание медиа, ссылок и структуры публикации.

Этот модуль выполняет только чистую обработку уже полученных объектов
Telegram и не обращается к сети.
"""
from __future__ import annotations

import re
from typing import Callable

from telethon.tl import types

from models import MediaItem, MediaType, ParsedMessage, VideoLink

_URL_RE = re.compile(r"(https?://[^\s]+)", re.IGNORECASE)

_YOUTUBE_DOMAINS = ("youtube.com", "youtu.be", "youtube-nocookie.com")
_RUTUBE_DOMAINS = ("rutube.ru",)
_VK_VIDEO_MARKERS = ("vk.com/video", "m.vk.com/video", "vkvideo.ru")

# Страницы конкретных роликов на YouTube (канал/плейлист/профиль — не видео).
_YOUTUBE_VIDEO_MARKERS = (
    "youtube.com/watch",
    "youtube.com/shorts/",
    "youtube.com/embed/",
    "youtube.com/live",
    "youtu.be/",
)


# ---------------------------------------------------------------------------
# Классификация ссылок и медиа
# ---------------------------------------------------------------------------

def extract_links(text: str | None) -> list[str]:
    """Все http(s) ссылки из текста, без хвостовой пунктуации."""
    if not text:
        return []
    found: list[str] = []
    for raw in _URL_RE.findall(text):
        url = raw.rstrip(".,!?;:)]}»\"'")
        if url and url not in found:
            found.append(url)
    return found


def classify_video_links(text: str | None) -> list[VideoLink]:
    """Из текста выделяет ссылки на видео youtube/rutube/vk.

    Каналы, плейлисты и профили (ru.tube.channel, youtube.com/@user и т.п.) —
    это НЕ видео-ролики, они видео-блоками не становятся.
    """
    result: list[VideoLink] = []
    for url in extract_links(text):
        lowered = url.lower()
        if any(d in lowered for d in _YOUTUBE_DOMAINS):
            # Только страницы роликов, а не канала/плейлиста/профиля.
            if not any(m in lowered for m in _YOUTUBE_VIDEO_MARKERS):
                continue
            provider = "youtube"
        elif any(d in lowered for d in _RUTUBE_DOMAINS):
            if "/video" not in lowered:
                continue  # канал, лента, плейлист — не ролик
            provider = "rutube"
        elif any(v in lowered for v in _VK_VIDEO_MARKERS):
            provider = "vk"
        else:
            continue
        result.append(VideoLink(url=url, provider=provider))
    return result


def classify_media_kind(message) -> tuple[MediaType | None, str | None]:
    """Определяет тип медиа сообщения или возвращает предупреждение.

    Возвращает (None, None) для сообщений без «файлового» медиа
    (например, только ссылка с превью).
    """
    media = message.media
    if media is None:
        return None, None

    if isinstance(media, types.MessageMediaPhoto):
        return MediaType.IMAGE, None

    if isinstance(media, types.MessageMediaDocument):
        doc = media.document
        mime = (getattr(doc, "mime_type", None) or "").lower()
        for attr in getattr(doc, "attributes", []) or []:
            if isinstance(attr, types.DocumentAttributeAudio):
                return MediaType.AUDIO, None  # голосовое или музыка
            if isinstance(attr, types.DocumentAttributeVideo):
                return MediaType.VIDEO, None
            if isinstance(attr, types.DocumentAttributeSticker):
                return MediaType.UNSUPPORTED, "стикер"
            if isinstance(attr, types.DocumentAttributeAnimated) and mime.startswith("video/"):
                return MediaType.VIDEO, None  # анимированный GIF (mp4)
        if mime.startswith("image/"):
            return MediaType.IMAGE, None
        if mime.startswith("audio/"):
            return MediaType.AUDIO, None
        if mime.startswith("video/"):
            return MediaType.VIDEO, None
        # Всё остальное (pdf, docx, zip и т.п.) — обычный файл.
        return MediaType.FILE, None

    if isinstance(media, types.MessageMediaWebPage):
        # Превью ссылки — отдельного файла нет; обрабатывается как ссылка в тексте.
        return None, None

    if isinstance(media, types.MessageMediaPoll):
        return MediaType.UNSUPPORTED, "poll (опрос)"
    if isinstance(media, types.MessageMediaUnsupported):
        return MediaType.UNSUPPORTED, "неподдерживаемый тип медиа"
    if isinstance(
        media, (types.MessageMediaGeo, types.MessageMediaGeoLive, types.MessageMediaVenue)
    ):
        return MediaType.UNSUPPORTED, "геолокация"
    if isinstance(media, types.MessageMediaContact):
        return MediaType.UNSUPPORTED, "контакт"
    if isinstance(media, types.MessageMediaGame):
        return MediaType.UNSUPPORTED, "игра"
    if isinstance(media, types.MessageMediaInvoice):
        return MediaType.UNSUPPORTED, "инвойс"
    return MediaType.UNSUPPORTED, f"тип {type(media).__name__}"


# ---------------------------------------------------------------------------
# Сборка ParsedMessage из одного сообщения или альбома
# ---------------------------------------------------------------------------

def parse_group(messages: list, channel_username: str | None) -> ParsedMessage | None:
    """Превращает одно сообщение (или альбом) в ParsedMessage.

    `messages` — все сообщения одной публикации (медиа-группы), отсортированные
    по id (asc).
    """
    if not messages:
        return None

    messages = sorted(messages, key=lambda m: m.id)
    representative_id = messages[0].id
    date = messages[0].date

    # Служебные сообщения (закреп, создание канала и т.п.) не импортируем.
    if any(getattr(m, "action", None) is not None for m in messages):
        return ParsedMessage(
            message_id=representative_id,
            messages=messages,
            date=date,
            text=None,
            skip_reason="служебное сообщение (service message)",
        )

    # Текст: все непустые тексты группы, без дубликатов, в порядке сообщений.
    texts: list[str] = []
    for m in messages:
        text = (getattr(m, "text", None) or "").strip()
        if text and text not in texts:
            texts.append(text)
    text = "\n\n".join(texts) if texts else None

    # Если текста нет, но есть ссылка-превью — сохраняем URL как текст,
    # чтобы ссылка не потерялась.
    if not text:
        for m in messages:
            web = m.media
            if isinstance(web, types.MessageMediaWebPage) and getattr(web, "url", None):
                text = web.url
                break

    media: list[MediaItem] = []
    warnings: list[str] = []
    for m in messages:
        kind, warning = classify_media_kind(m)
        if kind is None:
            continue
        mime = None
        file_name = None
        if isinstance(m.media, types.MessageMediaDocument):
            doc = m.media.document
            mime = getattr(doc, "mime_type", None) or None
            for attr in getattr(doc, "attributes", []) or []:
                if isinstance(attr, types.DocumentAttributeFilename):
                    file_name = getattr(attr, "file_name", None)
        elif isinstance(m.media, types.MessageMediaPhoto):
            mime = "image/jpeg"
        if warning:
            warnings.append(f"сообщение {m.id}: {warning}")
        media.append(
            MediaItem(
                kind=kind,
                message_id=m.id,
                file_name=file_name,
                mime_type=mime,
                warning=warning,
                message=m,
            )
        )

    video_links = classify_video_links(text or "")

    supported_media = [m for m in media if m.kind is not MediaType.UNSUPPORTED]

    # Если по сути нечего импортировать — помечаем публикацию как «пропуск».
    if not text and not video_links and not supported_media:
        why = "; ".join(warnings) if warnings else "пустое сообщение / неизвестный медиа"
        return ParsedMessage(
            message_id=representative_id,
            messages=messages,
            date=date,
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
        messages=messages,
        date=date,
        text=text,
        media=media,
        video_links=video_links,
        warnings=warnings,
        source_url=source_url,
        skip_reason=None,
    )


# ---------------------------------------------------------------------------
# Решение о том, что получится в Supabase
# ---------------------------------------------------------------------------

def decide_publication_type(parsed: ParsedMessage) -> str:
    """Определяет publications.type по содержимому публикации."""
    kinds = {m.kind for m in parsed.media}
    has_text = bool(parsed.text and parsed.text.strip())
    supported = parsed.supported_media

    # фото-публикация: ровно одна картинка и больше ничего
    if (
        not has_text
        and not parsed.video_links
        and len(supported) == 1
        and kinds == {MediaType.IMAGE}
    ):
        return "photo"

    # аудио: есть аудио-файл (голосовое/музыка) и нет картинок/видео-файлов.
    # Ссылка на видео в тексте (например, тот же вәгазь на rutube) не меняет
    # природу поста — это аудио.
    if MediaType.AUDIO in kinds and not (
        MediaType.IMAGE in kinds or MediaType.VIDEO in kinds
    ):
        return "audio"

    # видео: видео-файл или видео-ссылка, без картинок
    if (MediaType.VIDEO in kinds or parsed.video_links) and not (MediaType.IMAGE in kinds):
        return "video"

    return "article"


def decide_icon(publication_type: str, parsed: ParsedMessage) -> str | None:
    """Иконка из зарегистрированных ключей приложения (AppIcons.paths)."""
    if publication_type == "audio":
        return "audio"
    if publication_type == "video":
        for link in parsed.video_links:
            if link.provider == "youtube":
                return "youtube"
            if link.provider == "rutube":
                return "rutube"
        return "video"
    if publication_type == "photo":
        return None  # photo-публикации показывают картинку, а не иконку
    return "book"


_TITLE_MAX = 60


def derive_title(text: str | None, message_id: int) -> str:
    """Заголовок для publications.title из текста публикации."""
    source = (text or "").strip()
    if source:
        first_line = next((l.strip() for l in source.splitlines() if l.strip()), source)
        # Убираем голые ссылки из заголовка
        title = re.sub(r"https?://\S+", "", first_line).strip()
        title = re.sub(r"\s{2,}", " ", title)
        if len(title) > _TITLE_MAX:
            title = title[:_TITLE_MAX - 1].rstrip() + "…"
        if title:
            return title
    return f"Публикация #{message_id}"


# ---------------------------------------------------------------------------
# Построение content_blocks
# ---------------------------------------------------------------------------

def build_block_rows(
    parsed: ParsedMessage,
    key_for: Callable[[MediaItem], str],
    public_url_for: Callable[[str], str],
    *,
    photo_publication: bool = False,
    size_for: Callable[[MediaItem], int | None] | None = None,
) -> list[dict]:
    """Строит строки для таблицы content_blocks.

    `key_for` — ключ S3, полученный после загрузки каждого MediaItem.
    `public_url_for` — строит публичный URL по ключу (для external-видео).
    `size_for` — размер файла в байтах (необязательно).
    Для photo-публикаций блоки не нужны (картинка лежит в photo_path).

    Фотографии Telegram media group (альбома) объединяются в ОДИН image-блок
    вида `{"paths": [key1, key2, ...]}` с сохранением порядка — так альбом из
    нескольких фото становится одним компактным PhotoContentBlock, а не
    несколькими блоками подряд. Одиночная картинка даёт `{"paths": [key]}`.

    Загруженные в S3 видео и файлы (pdf и т.п.) хранят ключ в `path`
    (как аудио upload), внешние видео — по-прежнему `url` + `provider`.
    """
    if photo_publication:
        return []

    rows: list[dict] = []
    order = 0

    def add(block_type: str, data: dict) -> None:
        nonlocal order
        rows.append({"type": block_type, "order_index": order, "data": data})
        order += 1

    def media_info(item: MediaItem) -> dict:
        info: dict = {}
        name = item.file_name or key_for(item).split("/")[-1]
        if name:
            info["name"] = name
        if item.mime_type:
            info["mime"] = item.mime_type
        size = size_for(item) if size_for else None
        if size is not None:
            info["size"] = size
        return info

    def add_media_items(items: list[MediaItem]) -> None:
        """Складывает media по порядку, склеивая подряд идущие картинки."""
        pending_images: list[MediaItem] = []

        def flush_images() -> None:
            if not pending_images:
                return
            keys = [key_for(item) for item in pending_images]
            add("image", {"paths": keys})
            pending_images.clear()

        for item in items:
            if item.kind is MediaType.IMAGE:
                pending_images.append(item)
                continue
            flush_images()
            key = key_for(item)
            if item.kind is MediaType.AUDIO:
                add("audio", {"source": "upload", "path": key})
            elif item.kind is MediaType.VIDEO:
                add("video", {"source": "upload", "path": key, **media_info(item)})
            elif item.kind is MediaType.FILE:
                add("file", {"path": key, **media_info(item)})
        flush_images()

    # В альбоме текст живёт на последнем фото — сохраняем порядок Telegram:
    # сначала медиа, затем описание.
    if parsed.is_album:
        add_media_items(list(parsed.supported_media))
        if parsed.text and parsed.text.strip():
            add("text", {"text": parsed.text})
    else:
        if parsed.text and parsed.text.strip():
            add("text", {"text": parsed.text})
        add_media_items(list(parsed.supported_media))

    for link in parsed.video_links:
        add("video", {"url": link.url, "provider": link.provider})

    return rows