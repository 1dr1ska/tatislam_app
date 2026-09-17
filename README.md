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

## Push-уведомления о новых публикациях (FCM)

Flutter-приложение отправляет FCM-токен устройства в Supabase (таблица
`notification_devices`, идемпотентный upsert по `fcm_token`). Когда импортёр
создаёт новую публикацию, он вызывает Edge Function `notify-new-publication`,
которая рассылает push зарегистрированным активным устройствам.

```
Flutter app (FCM token)
    ↓ register_notification_device (RPC)
Supabase: notification_devices
    ↓ при INSERT публикации
импортёр → Edge Function notify-new-publication
    ↓ FCM HTTP v1 (service account — секрет сервера)
Android / iOS
```

Ключевые свойства:

- **Уведомление при ПЕРВОЙ публикации**, а не при создании: push уходит, когда
  публикация получает статус `published` — сразу при создании (это дефолт и для
  импортёра, и для ручного редактора) или при переходе «черновик → опубликовано».
  Черновик — вспомогательный статус, он не отправляет и не блокирует push.
- **Идемпотентность.** Повторный запуск импортёра не создаёт дубликат
  (unique-индекс `publications.telegram_message_id`), а повторный вызов Edge
  Function не шлёт повторный push (RPC `claim_publication_notification`:
  `insert … on conflict (publication_id) do nothing`).
- **Payload уведомления:** `type=new_publication`, `publication_id`,
  `publication_type`, `publication_title`. По тапу приложение открывает
  `/publication/:id` (существующий go_router).
- **Настройка «Уведомления о новых публикациях»** (экран «О приложении»):
  выключение переводит `notification_devices.is_active = false`, включение —
  регистрирует токен заново.
- **Секреты** (Firebase service account, ключи) живут только на backend.
- Невалидные FCM-токены автоматически деактивируются Edge Function.

### Настройка (делается вручную)

1. **Firebase Console**: создайте проект Firebase (или используйте
   существующий); добавьте Android-приложение (пакет `com.example.tatislam_app`)
   и скачайте `google-services.json` → положите в `android/app/google-services.json`.
2. **Android 13+**: разрешение `POST_NOTIFICATIONS` уже объявлено в
   `AndroidManifest.xml`; запрос выполняется автоматически при старте.
3. **Service account** (Firebase Console → Project settings → Service accounts →
   Generate new private key) → JSON одним значением в секрет Edge Function:
   `supabase secrets set --env-file ...` или Dashboard → Edge Functions →
   `notify-new-publication` → Secrets: `FIREBASE_SERVICE_ACCOUNT_JSON` (весь JSON
   одной строкой). Опционально `NOTIFICATION_TITLE` и `NOTIFICATION_BODY_PREFIX`.
4. **Применить миграцию**: из директории `supabase/` выполнить
   `supabase db push` (миграция `0028_push_notifications.sql`).
5. **Задеплоить функцию**: `supabase functions deploy notify-new-publication`.
6. **iOS** (отдельно): см. ниже.

### Ручной тест (Android)

1. Установить приложение, разрешить уведомления.
2. Проверить в Supabase (SQL Editor):
   `select * from notification_devices;` — должна появиться строка с
   `is_active = true` и вашим FCM-токеном.
3. Запустить импортёр для новой публикации.
4. Убедиться, что push пришёл, и нажать его → открывается экран публикации.
5. Повторно запустить импортёр — второй push НЕ приходит (строка уже есть в
   `publication_notifications`).
6. Выключить настройку «Уведомления о новых публикациях», импортировать ещё одну
   публикацию — push не приходит; `is_active` для устройства стал `false`.
7. Включить настройку обратно — `is_active = true`, push снова приходят.

### iOS (что потребуется)

- `GoogleService-Info.plist` из Firebase Console (iOS-приложение в том же
  проекте Firebase) → добавить в Xcode в таргет `Runner`.
- Xcode → Runner target → Signing & Capabilities:
  - **Push Notifications**;
  - **Background Modes → Remote notifications**.
- В Apple Developer Console: создать APNs Auth Key (или APNs certificate),
  загрузить его в Firebase Console (Cloud Messaging → iOS app settings → APNs).
- В `Info.plist` ничего специального не требуется (код уже вызывает
  `FirebaseApp.configure()` в `AppDelegate.swift`).

## CI/CD

GitHub Actions (`.github/workflows/`): при пуше в `main` собирается
веб-версия (`flutter build web --release`) и синхронизируется в Yandex
Object Storage через `aws s3 sync --delete`.

## Прочее

- Иконки приложения генерируются из `assets/images/app_icon.png`
  через `flutter_launcher_icons`.
- Тесты: `test/photo_publication_test.dart`, `test/audio_playback_speed_test.dart`.
