#!/usr/bin/env python3
"""CLI-вход импортёра Tatislam.

Примеры:
    # Режим Telegram (нужен TELEGRAM_API_ID/API_HASH)
    python main.py --dry-run --channel tatislam
    python main.py --limit 10 --channel tatislam
    python main.py --channel tatislam

    # Режим без Telegram API: официальный экспорт Telegram Desktop
    python main.py --source export --file /путь/к/result.json --dry-run
    python main.py --source export --file /путь/к/result.json --limit 10
    python main.py --source export --file /путь/к/result.json
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from pathlib import Path

from config import ConfigError, Settings
from importer import Importer
from telegram_client import TelegramClientWrapper


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="tatislam-importer",
        description="Одноразовый перенос публикаций Telegram-канала в Tatislam "
        "(Supabase + Yandex Object Storage).",
    )
    parser.add_argument(
        "--source",
        choices=("telegram", "export"),
        default="telegram",
        help="Источник данных: telegram (по умолчанию; нужен API) или export "
        "(официальный экспорт Telegram Desktop).",
    )
    parser.add_argument(
        "--file",
        metavar="PATH",
        default=None,
        help="Путь к result.json экспорта Telegram Desktop (для --source export).",
    )
    parser.add_argument(
        "--channel",
        "-c",
        help="Канал: @username, ссылка https://t.me/... или числовой id. "
        "По умолчанию TELEGRAM_CHANNEL из .env. Для --source export используется "
        "только как username для построения ссылок на публикации.",
    )
    parser.add_argument(
        "--limit",
        "-l",
        type=int,
        default=None,
        help="Импортировать только последние N сообщений/публикаций (для теста).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Только прочитать и проанализировать: ничего не качать, не загружать "
        "и не писать в БД.",
    )
    parser.add_argument(
        "--section",
        help="slug секции Supabase для публикаций (по умолчанию DEFAULT_SECTION_SLUG из .env).",
    )
    return parser


async def amain(args: argparse.Namespace) -> int:
    settings = Settings.load()

    # ---- Режим экспорта: API Telegram не нужен вообще -------------------
    if args.source == "export":
        if not args.file:
            print(
                "Укажите файл экспорта: --source export --file /путь/к/result.json",
                file=sys.stderr,
            )
            return 2
        export_path = Path(args.file)
        if not export_path.is_file():
            print(f"Файл экспорта не найден: {export_path}", file=sys.stderr)
            return 2
        importer = Importer(
            settings,
            telegram=None,
            dry_run=args.dry_run,
            section_slug=args.section,
        )
        await importer.run_export(
            export_path=str(export_path),
            limit=args.limit,
            channel_hint=args.channel,
        )
        return 0

    # ---- Режим Telegram --------------------------------------------------
    if not settings.telegram_api_id or not settings.telegram_api_hash:
        raise ConfigError(
            "В .env не заполнены TELEGRAM_API_ID / TELEGRAM_API_HASH. "
            "Они нужны только для режима --source telegram. Если получить их "
            "не получается — используйте официальный экспорт Telegram Desktop: "
            "python main.py --source export --file /путь/к/result.json"
        )

    channel = args.channel or settings.default_channel
    if not channel:
        print(
            "Укажите канал: --channel 'имя' или TELEGRAM_CHANNEL в .env",
            file=sys.stderr,
        )
        return 2

    telegram = TelegramClientWrapper(
        api_id=settings.telegram_api_id,
        api_hash=settings.telegram_api_hash,
        session_file=settings.session_file,
    )
    try:
        await telegram.connect_and_authorize()
        importer = Importer(
            settings,
            telegram,
            dry_run=args.dry_run,
            section_slug=args.section,
        )
        await importer.run(channel_spec=channel, limit=args.limit)
    finally:
        await telegram.disconnect()
    return 0


def main() -> int:
    # Отдельные уровни логирования раскрашивать не требуется: в сообщениях уже
    # есть собственные теги ([INFO], [SKIP], [OK], [ERROR], [WARN]).
    logging.basicConfig(
        level=logging.INFO,
        format="%(message)s",
        handlers=[logging.StreamHandler(sys.stdout)],
    )
    parser = build_parser()
    args = parser.parse_args()
    try:
        return asyncio.run(amain(args))
    except ConfigError as exc:
        print(f"Ошибка конфигурации: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("\nПрервано пользователем.")
        return 130
    except Exception as exc:
        logging.getLogger("importer").error("Необработанная ошибка: %s", exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())