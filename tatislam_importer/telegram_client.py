"""Тонкая обёртка над Telethon: авторизация и получение сообщений канала.

Номер телефона не хранится нигде — он запрашивается интерактивно при
первой авторизации, сессия сохраняется в файле (telegram.session по умолчанию).
"""
from __future__ import annotations

import logging
from pathlib import Path

from telethon import TelegramClient

logger = logging.getLogger("importer")


class TelegramClientWrapper:
    def __init__(self, api_id: int, api_hash: str, session_file: str) -> None:
        self._client = TelegramClient(str(session_file), api_id, api_hash)
        self.channel_username: str | None = None

    # ------------------------------------------------------------------
    # Авторизация
    # ------------------------------------------------------------------

    async def connect_and_authorize(self) -> None:
        await self._client.connect()
        if not await self._client.is_user_authorized():
            logger.info("[INFO] Первая авторизация. Нужен номер телефона и код.")
            await self._client.start(
                phone=lambda: input("Номер телефона (например +79001234567): ").strip(),
                code_callback=lambda: input("Код из Telegram: ").strip(),
                password=lambda: input("Пароль 2FA (если включён): ").strip(),
            )
            logger.info("[INFO] Сессия сохранена — повторная авторизация не понадобится.")
        logger.info("[INFO] Connected to Telegram")

    # ------------------------------------------------------------------
    # Канал
    # ------------------------------------------------------------------

    async def resolve_channel(self, channel_spec: str):
        """Разрешает username/id/пригласительную ссылку в объект канала."""
        raw = str(channel_spec).strip()
        if raw.startswith("https://t.me/"):
            raw = raw[len("https://t.me/") :]
        elif raw.startswith("t.me/"):
            raw = raw[5:]
        raw = raw.split("?")[0].rstrip("/").lstrip("@")
        if not raw:
            raise ValueError(f"Не удалось разобрать канал: {channel_spec!r}")

        entity = await self._client.get_entity(raw)
        self.channel_username = getattr(entity, "username", None)
        logger.info(
            "[INFO] Resolved channel: %s (username=%s, id=%s)",
            getattr(entity, "title", raw),
            self.channel_username,
            getattr(entity, "id", None),
        )
        return entity

    # ------------------------------------------------------------------
    # Сообщения
    # ------------------------------------------------------------------

    async def fetch_messages(self, channel, limit: int | None = None) -> list:
        """Возвращает сообщения канала от старых к новым.

        `limit=None` — вся история канала. `limit=N` — последние N сообщений.
        """
        messages: list = []
        async for message in self._client.iter_messages(channel, limit=limit):
            messages.append(message)
        # iter_messages отдаёт новые → старые; переворачиваем для хронологии.
        messages.reverse()
        return messages

    async def download_media(self, message, directory: str) -> Path | None:
        """Скачивает медиа сообщения в directory и возвращает путь к файлу."""
        result = await self._client.download_media(message, file=directory)
        if isinstance(result, str):
            path = Path(result)
            if path.is_file():
                return path
        return None

    async def disconnect(self) -> None:
        await self._client.disconnect()