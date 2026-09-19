"""Тесты разбора Telegram-сообщений: фотоальбомы объединяются в один блок.

Запуск (из каталога tatislam_importer):
    .venv/bin/python -m unittest discover -s tests -t .
"""
from __future__ import annotations

import unittest
from datetime import datetime, timezone

from models import MediaItem, MediaType, ParsedMessage
from parser import build_block_rows, decide_publication_type


def _image(message_id: int) -> MediaItem:
    return MediaItem(kind=MediaType.IMAGE, message_id=message_id)


def _audio(message_id: int) -> MediaItem:
    return MediaItem(kind=MediaType.AUDIO, message_id=message_id)


def _video(message_id: int) -> MediaItem:
    return MediaItem(kind=MediaType.VIDEO, message_id=message_id)


def _parsed(media: list[MediaItem], *, text: str | None = None, album: bool = False) -> ParsedMessage:
    # is_album определяется по числу исходных сообщений группы.
    messages = [1, 2, 3, 4] if album else [1]
    return ParsedMessage(
        message_id=1,
        messages=messages,
        date=datetime(2024, 1, 1, tzinfo=timezone.utc),
        text=text,
        media=media,
        video_links=[],
    )


def _key_for(item: MediaItem) -> str:
    return f"images/{item.message_id}.jpg"


class BuildBlockRowsTest(unittest.TestCase):
    """Один Telegram media group → один image-блок с paths."""

    def test_media_group_becomes_one_image_block(self) -> None:
        parsed = _parsed([_image(10), _image(11), _image(12)], album=True)

        rows = build_block_rows(
            parsed,
            key_for=_key_for,
            public_url_for=lambda key: f"https://media/{key}",
        )

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["type"], "image")
        self.assertEqual(rows[0]["order_index"], 0)
        self.assertEqual(
            rows[0]["data"],
            {"paths": ["images/10.jpg", "images/11.jpg", "images/12.jpg"]},
        )

    def test_media_group_order_is_preserved(self) -> None:
        # Намеренно «перемешанный» список: порядок группы должен сохраниться.
        parsed = _parsed([_image(3), _image(1), _image(2)], album=True)

        rows = build_block_rows(
            parsed,
            key_for=_key_for,
            public_url_for=lambda key: key,
        )

        self.assertEqual(
            rows[0]["data"]["paths"],
            ["images/3.jpg", "images/1.jpg", "images/2.jpg"],
        )

    def test_single_photo_still_works(self) -> None:
        parsed = _parsed([_image(10)])

        rows = build_block_rows(
            parsed,
            key_for=_key_for,
            public_url_for=lambda key: key,
        )

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["type"], "image")
        self.assertEqual(rows[0]["data"], {"paths": ["images/10.jpg"]})

    def test_album_with_caption_keeps_text_after_media(self) -> None:
        parsed = _parsed([_image(10), _image(11)], text="Подпись", album=True)

        rows = build_block_rows(
            parsed,
            key_for=_key_for,
            public_url_for=lambda key: key,
        )

        self.assertEqual([r["type"] for r in rows], ["image", "text"])
        self.assertEqual(rows[1]["data"], {"text": "Подпись"})

    def test_non_album_photo_with_text(self) -> None:
        parsed = _parsed([_image(10)], text="Пост с фото")

        rows = build_block_rows(
            parsed,
            key_for=_key_for,
            public_url_for=lambda key: key,
        )

        self.assertEqual([r["type"] for r in rows], ["text", "image"])

    def test_mixed_media_keeps_grouping_and_order(self) -> None:
        # Фото, видео, фото → два image-блока по сторонам video-блока, а не
        # один склеенный блок через видео.
        parsed = _parsed([_image(10), _video(20), _image(11)])

        rows = build_block_rows(
            parsed,
            key_for=_key_for,
            public_url_for=lambda key: f"https://media/{key}",
        )

        self.assertEqual([r["type"] for r in rows], ["image", "video", "image"])
        self.assertEqual(rows[0]["data"], {"paths": ["images/10.jpg"]})
        self.assertEqual(rows[1]["data"]["provider"], "direct")
        self.assertEqual(rows[2]["data"], {"paths": ["images/11.jpg"]})

    def test_photo_publication_returns_no_blocks(self) -> None:
        parsed = _parsed([_image(10)])

        rows = build_block_rows(
            parsed,
            key_for=_key_for,
            public_url_for=lambda key: key,
            photo_publication=True,
        )

        self.assertEqual(rows, [])


class DecidePublicationTypeTest(unittest.TestCase):
    """Одиночное фото — фото-публикация; альбом — article с одним блоком."""

    def test_single_photo_without_text_is_photo_publication(self) -> None:
        parsed = _parsed([_image(10)])
        self.assertEqual(decide_publication_type(parsed), "photo")

    def test_pure_photo_album_is_article(self) -> None:
        parsed = _parsed([_image(10), _image(11)], album=True)
        self.assertEqual(decide_publication_type(parsed), "article")


if __name__ == "__main__":
    unittest.main()