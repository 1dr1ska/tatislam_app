"""Тесты сопоставления разделов: тип публикации → slug секции.

Запуск (из каталога tatislam_importer):
    .venv/bin/python -m unittest discover -s tests -t .
"""
from __future__ import annotations

import unittest

from importer import Importer


class _FakeSettings:
    default_section_slug = "articles"
    section_audio_slug = "audio"
    section_video_slug = "video"
    section_photo_slug = "rasemnar"


class SectionMappingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.importer = Importer.__new__(Importer)
        self.importer._section_cache = {}
        self.importer.settings = _FakeSettings()
        self.importer.section_slug = _FakeSettings.default_section_slug

    def test_article_uses_default_section(self) -> None:
        self.assertEqual(self.importer._section_slug_for("article"), "articles")

    def test_audio_uses_audio_section(self) -> None:
        self.assertEqual(self.importer._section_slug_for("audio"), "audio")

    def test_video_uses_video_section(self) -> None:
        self.assertEqual(self.importer._section_slug_for("video"), "video")

    def test_photo_uses_rasemnar_section(self) -> None:
        self.assertEqual(self.importer._section_slug_for("photo"), "rasemnar")

    def test_fallback_when_settings_have_no_section_fields(self) -> None:
        # Старые конфиги без новых полей не должны падать.
        importer = Importer.__new__(Importer)
        simple = type("S", (), {"default_section_slug": "articles"})()
        importer.settings = simple
        importer.section_slug = "articles"
        importer._section_cache = {}
        self.assertEqual(importer._section_slug_for("audio"), "audio")
        self.assertEqual(importer._section_slug_for("video"), "video")
        self.assertEqual(importer._section_slug_for("photo"), "rasemnar")
        self.assertEqual(importer._section_slug_for("article"), "articles")


if __name__ == "__main__":
    unittest.main()