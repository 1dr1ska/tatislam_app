# Tatislam Telegram Importer

Одноразовый инструмент переноса публикаций Telegram-канала в проект Tatislam.

```
Telegram channel
    ↓  Telethon (API, user session)
Python importer
    ↓  анализ публикации
Yandex Object Storage (S3)  ← медиа (как и прод-приложение)
    ↓  ключи images/…, audio/…, videos/…
Supabase PostgreSQL          ← publications + content_blocks + publication_sections
    ↓
Tatislam App
```

> **Важно.** Приложение Tatislam хранит медиа в **Yandex Object Storage**
> (`tatislam-media`), а не в Supabase Storage. Импортёр пишет в тот же бакет
> и сохраняет в БД те же ключи (`images/<uuid>.jpg` и т.п.), поэтому
> импортированный контент сразу корректно отображается в приложении.

## Структура

```
tatislam_importer/
├── main.py            # CLI: --channel, --limit, --dry-run, --section
├── config.py          # чтение .env
├── models.py          # dataclasses
├── parser.py          # разбор Telegram-сообщений (медиа, ссылки, тип публикации)
├── telegram_client.py # авторизация Telethon + получение сообщений
├── importer.py        # оркестрация импорта, идемпотентность, отчёт
├── supabase_client.py # записи в Supabase (service role)
├── media_storage.py   # загрузка в Yandex Object Storage (boto3)
├── requirements.txt
├── .env.example
└── .gitignore
```

Небольшая миграция БД: `supabase/migrations/0027_add_telegram_message_id.sql`
(добавляет `telegram_message_id` и `source_url` в `publications`).

---

## 1. Telegram API credentials

1. Зайдите на https://my.telegram.org → **API development tools**.
2. Создайте приложение — получите `api_id` (число) и `api_hash`.

## 2. Настройка .env

```bash
cp .env.example .env
```

Заполните `.env`:

```ini
TELEGRAM_API_ID=123456
TELEGRAM_API_HASH=abcdef...
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
YANDEX_ACCESS_KEY=...
YANDEX_SECRET_KEY=...
```

- `SUPABASE_SERVICE_ROLE_KEY` — «Settings → API → service_role». Ключ обходит RLS;
  годится **только** для серверного миграционного инструмента.
- `YANDEX_*` — статические ключи сервисного аккаунта Cloud с правом записи в
  бакет `tatislam-media` (как в настройках приложения).
- Необязательные параметры: `TELEGRAM_CHANNEL`, `SESSION_FILE`,
  `DEFAULT_SECTION_SLUG` (по умолчанию `articles`), `PUBLICATION_STATUS`
  (`published`/`draft`).

`.env` в Git не коммитится (см. `.gitignore`).

## 3. Установка зависимостей

```bash
cd tatislam_importer
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 4. Авторизация

```bash
python main.py --dry-run --channel @канал
```

При первом запуске Telethon попросит номер телефона и код подтверждения.
Сессия сохранится в `telegram.session` — дальше авторизация не требуется.
Номер телефона нигде не хранится в коде.

## 5. Dry-run

```bash
python main.py --dry-run --channel @канал
```

Ничего не скачивается, не загружается и не пишется в БД. Выводится план:

```
Message 123
  type: publication
  text: yes
  images: 3
  audio: no
  video: yes
  action: IMPORT
```

## 6. Импорт первых 10 сообщений

```bash
python main.py --channel @канал --limit 10
```

Возьмутся **последние 10** сообщений канала.

## 7. Полный импорт

```bash
python main.py --channel @канал
```

Весь канал в хронологическом порядке (старые → новые).
Канал можно указать один раз в `.env` как `TELEGRAM_CHANNEL` и не передавать
`--channel`.

## 8. Повторный запуск

Запустите ту же команду повторно. Импортёр проверяет
`publications.telegram_message_id` и пропускает уже импортированное:

```
[SKIP] message 100 уже импортировано
```

Любая публикация импортируется ровно один раз.

## 9. Просмотр ошибок

Каждая ошибка не останавливает импорт. В конце выводится отчёт:

```
========================================
Imported: 120
Skipped: 3
Errors: 1

Errors:
  - {'message_id': 77, 'source_url': 'https://t.me/...', 'error': '...'}
```

Ошибки дублируются построчно в `errors.jsonl` (добавляются при каждом запуске).
Чтобы повторить неудачные публикации — просто запустите импорт ещё раз.

---

## Как публикации ложатся в БД

| Telegram | publications.type | content_blocks |
|---|---|---|
| только текст | `article` | text |
| текст + картинка | `article` | text, image(path) |
| несколько фото (альбом) | `article` | image…, text (как в Telegram) |
| текст + аудио/голосовое | `audio` (если только аудио) | text, audio(upload) |
| текст + видео | `video` (если только видео) | text, video(direct → файл в S3) |
| YouTube/Rutube/VK ссылка | `video` | video с {url, provider} |
| фото без текста (одно) | `photo` | photo_path в publications |

- **id (publications)**: сохраняется `telegram_message_id` и `source_url`
  (`https://t.me/<channel>/<id>`); для альбомов — id первого сообщения.
- **Медиа**: скачивается в temp, заливается в `images/|audio/|videos/<uuid>.<ext>`
  (public-read), в БД пишутся **ключи**, а не URL.
- **Неизвестные типы** (документы, стикеры, опросы и т.п.): не падают —
  записывается предупреждение, публикация (текст/остальное) импортируется,
  а «неизвестное» пропускается. Если импортировать нечего — сообщение
  попадает в `Skipped` с причиной.
- **Блоки и секции** создаются только если создание `publications` успешно;
  при ошибке строка удаляется (FK каскад), поэтому повторный запуск
  корректно повторит попытку.
- **Заголовок** берётся из первой строки текста (обрезается до ~60 символов),
  иначе `Публикация #<id>`.
- **Иконка**: article→`book`, audio→`audio`, video→`video`/`youtube`/`rutube`.

## Известные ограничения v1

- Видео, загруженное в S3, отображается приложением как карточка
  «открыть в браузере» (provider `direct`) — инлайн-плеер поддерживается
  только для youtube/rutube.
- При `--limit` альбом может оказаться срезанным (если в выборку попала
  только часть его фото).
- `errors.jsonl` растёт между запусками — при необходимости очистите
  файл вручную.

## Примечание о базе данных

Требуется миграция `supabase/migrations/0027_add_telegram_message_id.sql`
(`telegram_message_id`, `source_url`, partial unique index). Остальная схема
используется как есть — новые таблицы/колонки не добавляются.