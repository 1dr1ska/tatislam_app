"""Доступ к Supabase PostgreSQL через service role key.

Service role key используется только здесь — в серверном миграционном
инструменте, чтобы обойти RLS (RLS оставляет запись только админам приложения).
"""
from __future__ import annotations

from supabase import create_client


class SupabaseClient:
    def __init__(self, url: str, service_role_key: str) -> None:
        self._client = create_client(url, service_role_key)

    # ----------------------------------------------------------
    # Чтение
    # ----------------------------------------------------------

    def get_section_id(self, slug: str) -> str:
        """Возвращает id секции по slug (например 'articles')."""
        response = self._client.table("sections").select("id").eq("slug", slug).limit(1).execute()
        rows = response.data or []
        if not rows:
            sections = self._client.table("sections").select("slug").execute()
            available = ", ".join(row["slug"] for row in (sections.data or [])) or "нет секций"
            raise RuntimeError(
                f"Секция '{slug}' не найдена в БД. Доступные slug: {available}. "
                "Укажите другую в .env (DEFAULT_SECTION_SLUG) или --section."
            )
        return rows[0]["id"]

    def has_message(self, telegram_message_id: int) -> bool:
        """Есть ли уже публикация с таким telegram_message_id (идемпотентность)."""
        response = (
            self._client.table("publications")
            .select("id")
            .eq("telegram_message_id", telegram_message_id)
            .limit(1)
            .execute()
        )
        return bool(response.data)

    # ----------------------------------------------------------
    # Запись
    # ----------------------------------------------------------

    def create_publication(self, row: dict) -> dict:
        """Создаёт строку в publications и возвращает её (включая id)."""
        response = self._client.table("publications").insert(row).execute()
        data = response.data or []
        if not data:
            raise RuntimeError("Create publication вернул пустой ответ PostgREST")
        return data[0]

    def insert_content_blocks(self, rows: list[dict]) -> None:
        """Массовая вставка content_blocks для одной публикации."""
        if not rows:
            return
        self._client.table("content_blocks").insert(rows).execute()

    def add_section_membership(self, publication_id: str, section_id: str) -> None:
        """Связь публикации с её основной секцией (publication_sections)."""
        self._client.table("publication_sections").insert(
            {"publication_id": publication_id, "section_id": section_id}
        ).execute()

    def delete_publication(self, publication_id: str) -> None:
        """Удаляет конкретную публикацию (каскадно — её блоки и секции)."""
        self._client.table("publications").delete().eq("id", publication_id).execute()

    def delete_by_telegram_id(self, telegram_message_id: int) -> None:
        """Откат частично созданной публикации при ошибке импорта.

        content_blocks и publication_sections удаляются каскадно по FK.
        """
        self._client.table("publications").delete().eq(
            "telegram_message_id", telegram_message_id
        ).execute()

    @property
    def client(self):
        return self._client