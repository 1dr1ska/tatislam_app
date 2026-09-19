"""Конфигурация импортёра Tatislam.

Все секреты читаются из .env (см. .env.example) и никогда не прописаны в коде.
"""
from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


class ConfigError(RuntimeError):
    """Ошибка конфигурации: не хватает переменной окружения или она неверна."""


def _env(name: str) -> str | None:
    value = os.getenv(name)
    if value is None or value.strip() == "":
        return None
    return value.strip()


@dataclass(frozen=True)
class Settings:
    # Telegram (нужны только для режима --source telegram)
    telegram_api_id: int | None
    telegram_api_hash: str | None

    # Supabase (нужны для реальной записи в БД)
    supabase_url: str | None
    supabase_service_role_key: str | None

    # Yandex Object Storage (нужны для реальной загрузки медиа)
    yandex_access_key: str | None
    yandex_secret_key: str | None

    # Необязательные, со здравыми значениями по умолчанию
    session_file: str
    default_channel: str | None
    default_section_slug: str
    publication_status: str
    push_notifications_enabled: bool
    yandex_bucket: str
    yandex_endpoint: str
    yandex_region: str

    @staticmethod
    def load() -> "Settings":
        api_id_raw = _env("TELEGRAM_API_ID")
        telegram_api_id: int | None = None
        if api_id_raw:
            try:
                telegram_api_id = int(api_id_raw)
            except ValueError as exc:
                raise ConfigError("TELEGRAM_API_ID должна быть числом") from exc

        status = _env("PUBLICATION_STATUS") or "published"
        if status not in ("draft", "published"):
            raise ConfigError(
                f"PUBLICATION_STATUS должно быть 'draft' или 'published', получено: {status}"
            )

        push_raw = (_env("PUSH_NOTIFICATIONS_ENABLED") or "true").strip().lower()
        if push_raw in ("1", "true", "yes", "on"):
            push_enabled = True
        elif push_raw in ("0", "false", "no", "off"):
            push_enabled = False
        else:
            raise ConfigError(
                f"PUSH_NOTIFICATIONS_ENABLED должно быть true/false, получено: {push_raw}"
            )

        return Settings(
            telegram_api_id=telegram_api_id,
            telegram_api_hash=_env("TELEGRAM_API_HASH"),
            supabase_url=_env("SUPABASE_URL"),
            supabase_service_role_key=_env("SUPABASE_SERVICE_ROLE_KEY"),
            yandex_access_key=_env("YANDEX_ACCESS_KEY"),
            yandex_secret_key=_env("YANDEX_SECRET_KEY"),
            session_file=_env("SESSION_FILE") or "telegram.session",
            default_channel=_env("TELEGRAM_CHANNEL"),
            default_section_slug=_env("DEFAULT_SECTION_SLUG") or "articles",
            publication_status=status,
            push_notifications_enabled=push_enabled,
            yandex_bucket=_env("YANDEX_BUCKET") or "tatislam-media",
            yandex_endpoint=_env("YANDEX_ENDPOINT") or "https://storage.yandexcloud.net",
            yandex_region=_env("YANDEX_REGION") or "ru-central1",
        )