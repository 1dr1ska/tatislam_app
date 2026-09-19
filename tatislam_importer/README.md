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

У импортёра **два источника данных**:

| Источник | Команда | Требования |
|---|---|---|
| Telegram API (Telethon) | `python main.py --channel @канал` | `TELEGRAM_API_ID/HASH` + авторизация |
| **Экспорт Telegram Desktop** | `python main.py --source export --file result.json` | **API не нужен вовсе** |

Режим `--source export` пригодится, если my.telegram.org не даёт получить
API-ключи — см. раздел «Импорт без Telegram API».

## Структура

```
tatislam_importer/
├── main.py            # CLI: --source, --file, --channel, --limit, --dry-run, --section
├── config.py          # чтение .env
├── models.py          # dataclasses
├── parser.py          # разбор Telegram-сообщений (медиа, ссылки, тип публикации)
├── export_reader.py   # разбор result.json (экспорт Telegram Desktop, без API)
├── telegram_client.py # авторизация Telethon + получение сообщений
├── importer.py        # оркестрация импорта, идемпотентность, отчёт
├── supabase_client.py # записи в Supabase (service role)
├── media_storage.py   # загрузка в Yandex Object Storage (boto3)
├── requirements.txt
├── .env.example
└── .gitignore
```

Небольшие миграции БД: `supabase/migrations/0027_add_telegram_message_id.sql`
(идемпотентность) и `0028_file_blocks_and_uploaded_video.sql` (file-блоки и
загрузка видео в Storage).

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

- `TELEGRAM_API_ID/HASH` нужны **только** для режима `--source telegram`.
  Если вы импортируете из `--source export` — их можно не заполнять.
- `SUPABASE_SERVICE_ROLE_KEY` — «Settings → API → service_role». Ключ обходит RLS;
  годится **только** для серверного миграционного инструмента. Для dry-run
  не требуется.
- `YANDEX_*` — статические ключи сервисного аккаунта Cloud с правом записи в
  бакет `tatislam-media` (как в настройках приложения). Для dry-run не требуются.
- Необязательные параметры: `TELEGRAM_CHANNEL`, `SESSION_FILE`,
  `DEFAULT_SECTION_SLUG` (по умолчанию `articles`), `PUBLICATION_STATUS`
  (`published`/`draft`), `PUSH_NOTIFICATIONS_ENABLED` (true/false — отправка
  push-уведомлений через Edge Function после импорта каждой публикации).
- Разделы выбираются по типу публикации автоматически:
  `SECTION_AUDIO_SLUG` (`audio`), `SECTION_VIDEO_SLUG` (`video`),
  `SECTION_PHOTO_SLUG` (`rasemnar`); для article используется
  `DEFAULT_SECTION_SLUG`. Переопределяются в `.env`.

`.env` в Git не коммитится (см. `.gitignore`).

## 3. Установка зависимостей

```bash
cd tatislam_importer
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 4. Авторизация (только для `--source telegram`)

```bash
python main.py --dry-run --channel @канал
```

При первом запуске Telethon попросит номер телефона и код подтверждения.
Сессия сохранится в `telegram.session` — дальше авторизация не требуется.
Номер телефона нигде не хранится в коде.
Для `--source export` авторизация и API вообще не нужны.

## 4а. Импорт без Telegram API (`--source export`)

Если получить настройки на https://my.telegram.org/apps не получается (гео-блок,
нужен VPN, «слишком новый» аккаунт и т.п.) — используйте **официальный экспорт**
истории канала из Telegram Desktop. Экспорт не требует ни api_id, ни api_hash.

### Как сделать экспорт в Telegram Desktop

1. Откройте канал в **Telegram Desktop** (десктопное приложение, не web).
2. Нажмите «⋯» (меню канала) → **Export chat history**.
   Этот же пункт доступен в **Настройки → Продвинутые → Экспорт данных
   Telegram**, где можно выбрать конкретный чат/канал.
3. В окне экспорта:
   - **Message format**: выберите **JSON**;
   - отметьте все нужные типы медиа (фото, видео, аудио) — файлы сохранятся
     рядом с JSON в папках `photos/`, `video_files/`, `audio_files/`;
   - при необходимости ограничьте диапазон дат или лимит размера.
4. Нажмите **Export** и дождитесь завершения (для большого канала — дольше).
5. Результат: папка с файлом **`result.json`** (имеют значение именно
   `result.json` и папки медиа рядом с ним — не переставляйте их отдельно).

### Запуск импорта из экспорта

```bash
# Сначала — предпросмотр (ничего не пишется, можно без любых ключей в .env):
python main.py --source export --file /путь/к/result.json --dry-run

# Импорт последних 10 публикаций:
python main.py --source export --file /путь/к/result.json --limit 10

# Полный импорт:
python main.py --source export --file /путь/к/result.json
```

- `TELEGRAM_API_ID/HASH` не нужны; авторизация не выполняется.
- `--channel` используется только чтобы построить ссылки
  `https://t.me/<username>/<id>` в `source_url` (если канал не private).
- Идемпотентность, секции, статусы, медиа — всё работает так же, как в
  Telegram-режиме.

### Особенности формата экспорта

- **Альбомы**. В экспорте Telegram Desktop нет `grouped_id`, поэтому импортёр
  распознаёт фотоальбомы эвристикой: несколько подряд идущих сообщений с фото,
  где подпись есть максимум у одного из них, объединяются в одну публикацию
  с одним image-блоком (`paths: [...снимки...]`). Фото с собственной подписью
  между снимками — это отдельные посты, они не склеиваются.
- **Видео-файлы**. Если при экспорте не были отмечены видеофайлы, в JSON вместо
  пути стоит строка `(File not included...)` — такие публикации импортируются
  без видео (только текст), с предупреждением. Чтобы получить видео, повторите
  экспорт, отметив тип «Видео-файлы» в настройках экспорта.
- **Документы** (pdf/pptx/docx): сообщение импортируется с текстом, сам документ
  пропускается с предупреждением (приложение не умеет показывать такие файлы).

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

**Тип, иконка и раздел выбираются автоматически по содержимому:**

| Тип | Иконка | Раздел | Когда |
|---|---|---|---|
| `article` | ✅ `book` | Мәкаләләр (`articles`) | текст, текст+картинка, альбомы |
| `audio` | ✅ `audio` | Аудио (`audio`) | есть аудио/голосовое (даже если в тексте есть ссылка на видео) |
| `video` | ✅ `video`/`youtube`/`rutube` | Видео (`video`) | видео-файл или youtube/rutube/vk-ссылка |
| `photo` | — (картинка) | Рәсемнәр (`rasemnar`) | одно фото без текста |

Content blocks:

| Telegram | content_blocks |
|---|---|
| только текст | text |
| текст + картинка | text, image(`paths:[key]`) |
| несколько фото (альбом) | один image-блок `paths:[...]`, text (как в Telegram) |
| текст + аудио/голосовое | text, audio(upload) |
| текст + видео (файл) | text, video(source: upload, path) |
| YouTube/Rutube/VK ссылка | video с {url, provider} |
| документы (pdf, docx, …) | text, file(`paths`-ключ, name, mime, size) |
| фото без текста (одно) | photo_path в publications |

- **id (publications)**: сохраняется `telegram_message_id` и `source_url`
  (`https://t.me/<channel>/<id>`); для альбомов — id первого сообщения.
- **Медиа**: скачивается в temp, заливается в
  `images/|audio/|videos/|files/<uuid>.<ext>` (public-read), в БД пишутся
  **ключи**, а не URL.
- **Документы** (pdf/docx/pptx/zip и т.п.) — теперь полноценные file-блоки:
  файл загружается в Yandex (`files/...`), пользователь может скачать/открыть.
- **Неизвестные типы** (стикеры, опросы и т.п.): не падают — записывается
  предупреждение, публикация (текст/остальное) импортируется, а
  «неизвестное» пропускается. Если импортировать нечего — сообщение
  попадает в `Skipped` с причиной.
- **Блоки и секции** создаются только если создание `publications` успешно;
  при ошибке строка удаляется (FK каскад), поэтому повторный запуск
  корректно повторит попытку.
- **Заголовок** берётся из первой строки текста (обрезается до ~60 символов),
  иначе `Публикация #<id>`.
- **Иконка**: article→`book`, audio→`audio`, video→`video`/`youtube`/`rutube`.

## Тесты

Разбор сообщений (включая склейку фотоальбомов) покрыт unit-тестами:

```bash
.venv/bin/python -m unittest discover -s tests -t . -v
```

## Известные ограничения v1

- Видеофайл, загруженный в Yandex (`videos/...`), играется **инлайн-плеером**
  (HTML5 `<video>` внутри WebView на Android/iOS и как нативный элемент на
  Web). Если плеер по какой-то причине недоступен, отображается карточка
  «открыть в браузере».
- При `--limit` альбом может оказаться срезанным (если в выборку попала
  только часть его фото).
- `errors.jsonl` растёт между запусками — при необходимости очистите
  файл вручную.

## Примечание о базе данных

Требуются миграции:

- `0027_add_telegram_message_id.sql` — `telegram_message_id` и `source_url`
  (идемпотентность);
- `0028_file_blocks_and_uploaded_video.sql` — новый тип блока `file` и
  формат видео «загружено в Storage» (`source: upload` + `path`).

Остальная схема используется как есть — новые таблицы не добавляются.