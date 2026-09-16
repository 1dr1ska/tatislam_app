# TatIslam

Flutter-приложение исламской контент-платформы TatIslam: каталог публикаций
(статьи, аудио, видео, фото) с разделами, поиском, избранным и админ-панелью.

Локализация: русский, татарский, английский.

## Возможности

- **Публикации** — 4 типа: `article`, `audio`, `video`, `photo` (фото-публикации
  открываются на весь экран). Публикация может входить в основной раздел
  (`primary_section_id`) и в дополнительные разделы.
- **Контент-блоки** — тело публикации состоит из упорядоченного списка блоков:
  текст, изображение, видео (YouTube / RuTube / VK / прямой URL) и аудио
  (загруженное в хранилище или внешний URL).
- **Разделы** — управляемые из админки категории (имя, slug, видимость,
  порядок, фоновое изображение). Фон раздела формирует дизайн главного экрана
  (стеклянные панели / glassmorphism).
- **Главный экран** — единая точка входа: поиск, фильтры по типу публикации,
  сетка карточек и каталог (`?mode=catalog`).
- **Детальный экран** — полный просмотр публикации: текст, кэшируемые
  изображения, встроенные видео, аудиоплеер (регулировка скорости
  воспроизведения), просмотр изображений на весь экран.
- **Избранное** — хранится локально на устройстве (Hive), без синхронизации.
- **Скачивание и «поделиться»** — скачивание медиа в кэш с системным диалогом
  сохранения и шаринг через нативный диалог платформы.
- **Аутентификация** — вход/регистрация через Supabase Auth; раздел `/admin`
  доступен только пользователям с ролью администратора.
- **Админ-панель** (`/admin`) — CRUD публикаций, фото-публикаций и разделов,
  загрузка медиа с оптимизацией изображений.
- **Доступность** — масштабирование текста, локализация (ru / tt / en).

## Технологический стек

| Назначение            | Библиотека                                                        |
| --------------------- | ----------------------------------------------------------------- |
| Фреймворк             | Flutter (Material, Dart SDK `^3.12.2`)                            |
| Состояние / DI        | `flutter_riverpod`                                                |
| Маршрутизация         | `go_router` (пути вида `/publication/:id`, `/admin/**`)           |
| Бэкенд / БД / Auth    | `supabase_flutter` (PostgreSQL, RLS, Auth)                        |
| Локальное хранилище   | `hive` / `hive_flutter` (избранное, настройки, кэш разделов)      |
| Локализация           | `flutter_localizations`                                           |
| Аудио                | `just_audio`                                                      |
| Встроенные видео      | `webview_flutter` (YouTube / RuTube / VK iframe-эмбеды)           |
| Изображения           | `cached_network_image`, `image` (оптимизация/сжатие)              |
| Медиа-хранилище       | `http` + `http_parser` (загрузка в Yandex Object Storage)         |
| Скачивание / шаринг   | `share_plus`, `flutter_file_dialog`                               |

## Структура проекта

```
lib/
└── core/                        # Общее ядро
    ├── constants/               # Цвета, иконки, строки, имена таблиц/бакетов
    ├── navigation/              # app_router.dart — конфигурация go_router
    ├── providers/               # Глобальные провайдеры (локаль, масштаб текста)
    ├── services/                # Supabase, локальное хранилище (Hive),
    │                            #   оптимизация медиа, размеры изображений
    ├── storage/                 # Yandex Object Storage (S3) репозиторий
    ├── theme/                   # Тема приложения
    └── widgets/                 # Переиспользуемые виджеты
└── features/                    # Фичи (feature-first архитектура)
    ├── publications/            # Публикации: данные, домен, экраны
    ├── sections/                # Разделы контента
    ├── detail/                  # Детальный просмотр публикации
    ├── auth/                    # Аутентификация (data/domain/presentation)
    ├── admin/                   # Админ-панель и редакторы
    ├── favorites/               # Избранное (локальное, Hive)
    └── about/                   # Экран «О приложении»

supabase/
├── migrations/                  # 27 SQL-миграций (схема, RLS, view)
├── functions/upload-media/      # Edge Function: загрузка медиа в S3
└── seed.sql

tatislam_importer/               # Python-инструмент переноса контента
                                 # из Telegram-канала (см. его README.md)

test/                            # Тесты (фото-публикации, скорость аудио)
```

Внутри фич используется чистая архитектура: `data` (датасорсы, модели,
репозитории) → `domain` (сущности, use cases, интерфейсы) → `presentation`
(провайдеры, виджеты, экраны).

## Требования

- Flutter stable (SDK Dart `^3.12.2`, версия контрольной ревизии —
  см. `.metadata`)
- Доступ к Supabase-проекту (URL и publishable key зашиты в `lib/main.dart`)
- Для админ-загрузки медиа — развёрнутая Edge Function `upload-media`
  (переменные окружения `YANDEX_*` из `supabase/functions/.env`)

## Запуск

```sh
flutter pub get                # установить зависимости
flutter run                    # запустить приложение (дефолтная платформа)
flutter run -d web             # запустить веб-версию в debug
flutter build web --release    # продакшн-сборка веб-версии
```

Проверка и тесты:

```sh
flutter analyze
flutter test
```

## Бэкенд

- **Supabase** — PostgreSQL. Схема задана миграциями в `supabase/migrations/`
  (таблицы `profiles`, `sections`, `publications`, `content_blocks`,
  `publication_sections` + view `publications_by_section_view`, RLS-политики).
  Применение: `supabase db push` из директории `supabase/`.
- **Медиа-хранилище** — Yandex Object Storage (S3, бакет `tatislam-media`).
  В базе хранятся **пути** (например, `images/<uuid>.jpg`), а не URL;
  публичные URL формируются на лету репозиторием `MediaStorageRepository`.
  Загрузка файлов выполняется через Edge Function `upload-media`
  (валидирует папку `images|audio|videos|covers`, размер и MIME-тип).
- **Импорт из Telegram** — скрипт `tatislam_importer/` (Python, Telethon)
  переносит публикации Telegram-канала в ту же схему данных. Подробности:
  [tatislam_importer/README.md](tatislam_importer/README.md).

## CI/CD

GitHub Actions (`.github/workflows/`): при пуше в `main` собирается
веб-версия (`flutter build web --release`) и синхронизируется в Yandex
Object Storage через `aws s3 sync --delete`.

## Прочее

- Иконки приложения генерируются из `assets/images/app_icon.png`
  через `flutter_launcher_icons`.
- Тесты: `test/photo_publication_test.dart`, `test/audio_playback_speed_test.dart`.
