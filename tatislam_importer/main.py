#!/usr/bin/env python3
"""CLI-вход импортёра Tatislam.

Примеры:
    python main.py --dry-run --channel tatislam
    python main.py --limit 10 --channel tatislam
    python main.py --channel tatislam
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys

from config import ConfigError, Settings
from importer import Importer
from telegram_client import TelegramClientWrapper


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="tatislam-importer",
        description="Одноразовый перенос публикаций Telegram-канала в Tatislam (Supabase + Yandex Object Storage).",
    )
    parser.add_argument(
        "--channel",
        "-c",
        help="Канал: @username, ссылка https://t.me/... или числовой id. "
        "По умолчанию TELEGRAM_CHANNEL из .env.",
    )
    parser.add_argument(
        "--limit",
        "-l",
        type=int,
        default=None,
        help="Импортировать только последние N сообщений канала (для теста).",
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
    logging.basicConfig(
        level=logging.INFO,
        format="[%(levelname)s] %(message)s",
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