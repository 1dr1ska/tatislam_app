"""Dataclasses, используемые импортёром."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any


class MediaType(str, Enum):
    """Распознанные типы медиа в Telegram-сообщении."""

    IMAGE = "image"
    AUDIO = "audio"
    VIDEO = "video"
    FILE = "file"
    UNSUPPORTED = "unsupported"


@dataclass(frozen=True, eq=False)
class MediaItem:
    """Одно медиа внутри публикации (картинка/аудио/видео/неизвестное).

    `eq=False`: объекты сравниваются по идентичности. MediaItem используется
    как ключ словаря (item → S3-ключ), а его поле `message` (объект Telethon)
    не хешируемое — поэтому equality не должно включать поля.
    """

    kind: MediaType
    message_id: int
    file_name: str | None = None
    mime_type: str | None = None
    warning: str | None = None
    # Ссылка на исходный Telethon Message — нужна для скачивания байтов.
    message: Any = None
    # Локальный путь к файлу (режим импорта из экспорта Telegram Desktop).
    # Когда задан — качать из Telegram не нужно, файл уже на диске.
    local_path: str | None = None

    @property
    def folder(self) -> str:
        """Папка в Yandex Object Storage для этого типа медиа."""
        if self.kind is MediaType.IMAGE:
            return "images"
        if self.kind is MediaType.AUDIO:
            return "audio"
        if self.kind is MediaType.VIDEO:
            return "videos"
        if self.kind is MediaType.FILE:
            return "files"
        return "files"


@dataclass
class VideoLink:
    """Ссылка на внешнее видео (youtube/rutube/vk)."""

    url: str
    provider: str


@dataclass
class ParsedMessage:
    """Одна публикация канала (одно сообщение или медиа-группа/альбом).

    `message_id` — «представитель» публикации (минимальный id в группе).
    Именно он записывается в publications.telegram_message_id для
    идемпотентности.
    """

    message_id: int
    messages: list  # список исходных Telethon Message группы
    date: datetime
    text: str | None
    media: list[MediaItem] = field(default_factory=list)
    video_links: list[VideoLink] = field(default_factory=list)
    skip_reason: str | None = None
    warnings: list[str] = field(default_factory=list)
    source_url: str | None = None

    @property
    def is_album(self) -> bool:
        return len(self.messages) > 1

    @property
    def supported_media(self) -> list[MediaItem]:
        return [m for m in self.media if m.kind is not MediaType.UNSUPPORTED]


@dataclass
class ImportReport:
    """Итоговый отчёт одного запуска."""

    imported: int = 0
    skipped: int = 0
    errors: list[dict] = field(default_factory=list)

    def add_error(self, message_id: int, error: str, source_url: str | None) -> None:
        self.errors.append(
            {
                "message_id": message_id,
                "source_url": source_url,
                "error": error,
            }
        )