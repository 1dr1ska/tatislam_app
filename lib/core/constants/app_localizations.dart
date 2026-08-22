import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/providers/locale_provider.dart';

/// Centralized localization service for all UI strings.
///
/// Usage:
/// ```dart
/// final t = AppLocalizations.of(ref);
/// Text(t.settings);
/// ```
///
/// To add a third locale:
/// 1. Add a new value to [AppLocale] enum in locale_provider.dart.
/// 2. Add all switch cases for the new locale in this file.
class AppLocalizations {
  final AppLocale _locale;
  AppLocalizations._(this._locale);

  /// Creates [AppLocalizations] from a Riverpod [WidgetRef].
  static AppLocalizations of(WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return AppLocalizations._(locale);
  }

  /// Creates [AppLocalizations] from an [AppLocale] directly.
  static AppLocalizations fromLocale(AppLocale locale) {
    return AppLocalizations._(locale);
  }

  /// Always returns Russian locale — intended for admin screens.
  static AppLocalizations get admin => AppLocalizations._(AppLocale.russian);

  // ── Navigation & Tabs ───────────────────────────────────
  String get homeTab => _locale == AppLocale.tatar ? 'Баш бит' : 'Главная';
  String get catalogTab => _locale == AppLocale.tatar ? 'Каталог' : 'Каталог';
  String get searchTab => _locale == AppLocale.tatar ? 'Эзләргә' : 'Поиск';
  String get favoritesTab => _locale == AppLocale.tatar ? 'Сайланганнар' : 'Избранное';
  String get aboutTab => 'ТАТИСЛАМ';

  // ── Screen Titles ───────────────────────────────────────
  String get aboutScreenTitle => _locale == AppLocale.tatar ? 'Кушымта турында' : 'О приложении';
  String get loginScreenTitle => _locale == AppLocale.tatar ? 'Администратор керүе' : 'Вход администратора';
  String get registerScreenTitle => _locale == AppLocale.tatar ? 'Теркәлү' : 'Регистрация';
  String get createAccountTitle => _locale == AppLocale.tatar ? 'Аккаунт булдыру' : 'Создать аккаунт';
  String get adminPanelTitle => _locale == AppLocale.tatar ? 'Администратор панеле' : 'Панель администратора';
  String get publicationsTitle => _locale == AppLocale.tatar ? 'Башмалар' : 'Публикации';
  String get sectionsTitle => _locale == AppLocale.tatar ? 'Бүлекләр' : 'Разделы';
  String get newPublicationTitle => _locale == AppLocale.tatar ? 'Яңа башма' : 'Новая публикация';
  String get editPublicationTitle => _locale == AppLocale.tatar ? 'Башманы үзгәртү' : 'Редактировать публикацию';
  String get newPhotoTitle => _locale == AppLocale.tatar ? 'Яңа фото' : 'Новая фотопубликация';
  String get editPhotoTitle => _locale == AppLocale.tatar ? 'Фотоне үзгәртү' : 'Редактировать фотопубликацию';
  String get createSectionTitle => _locale == AppLocale.tatar ? 'Бүлек булдыру' : 'Создать раздел';
  String get editSectionTitle => _locale == AppLocale.tatar ? 'Бүлекне үзгәртү' : 'Редактировать раздел';
  String get deleteSectionTitle => _locale == AppLocale.tatar ? 'Бүлекне бетерү' : 'Удалить раздел';

  // ── Settings ────────────────────────────────────────────
  String get settings => _locale == AppLocale.tatar ? 'Көйләнмәләр' : 'Настройки';
  String get interfaceLanguage => _locale == AppLocale.tatar ? 'Интерфейс теле' : 'Язык интерфейса';
  String get textSize => _locale == AppLocale.tatar ? 'Текст зурлыгы' : 'Размер текста';
  String get tatarLanguageLabel => 'Татарча';
  String get russianLanguageLabel => 'Русский';

  // ── Search ──────────────────────────────────────────────
  String get searchHint => _locale == AppLocale.tatar ? 'Эзләү...' : 'Поиск...';
  String get noPublicationsFound => _locale == AppLocale.tatar ? 'Язмалар табылмады' : 'Публикации не найдены';
  String get noContent => _locale == AppLocale.tatar ? 'Эчтәлек юк' : 'Нет контента';
  String get noPublications => _locale == AppLocale.tatar ? 'Язмалар юк' : 'Нет публикаций';

  // ── Filters ─────────────────────────────────────────────
  String get allSections => _locale == AppLocale.tatar ? 'Барлык бүлекләр' : 'Все разделы';
  String get showFavorites => _locale == AppLocale.tatar ? 'Сайланганнар' : 'Избранное';
  String get showAll => _locale == AppLocale.tatar ? 'Барлык язмалар' : 'Все публикации';

  // ── Loading & Errors ────────────────────────────────────
  String get loading => _locale == AppLocale.tatar ? 'Төяү...' : 'Загрузка...';
  String get errorLoading => _locale == AppLocale.tatar ? 'Төяү хатасы' : 'Ошибка загрузки';
  String get needInternetForFirstLoad => _locale == AppLocale.tatar
      ? 'Беренче тапкыр төяү өчен интернетка тоташырга кирәк'
      : 'Для первой загрузки приложения требуется подключение к сети';
  String get retry => _locale == AppLocale.tatar ? 'Кабатлау' : 'Повторить';

  // ── Publication Actions ─────────────────────────────────
  String get share => _locale == AppLocale.tatar ? 'Уртаклашу' : 'Поделиться';
  String get addToFavorites => _locale == AppLocale.tatar ? 'Сайланганнарга өстәү' : 'Добавить в избранное';
  String get removeFromFavorites => _locale == AppLocale.tatar ? 'Сайланганнардан бетерү' : 'Удалить из избранного';
  String get publishedAt => 'Опубликовано: ';

  // ── Publication Types ───────────────────────────────────
  String get publicationTypeArticle => _locale == AppLocale.tatar ? 'Мәкалә' : 'Статья';
  String get publicationTypeVideo => _locale == AppLocale.tatar ? 'Видео' : 'Видео';
  String get publicationTypeAudio => _locale == AppLocale.tatar ? 'Аудио' : 'Аудио';

  // ── Admin: Statuses ─────────────────────────────────────
  String get statusDraft => _locale == AppLocale.tatar ? 'Каралама' : 'Черновик';
  String get statusPublished => _locale == AppLocale.tatar ? 'Басылган' : 'Опубликовано';
  String get statusField => _locale == AppLocale.tatar ? 'Хәләте' : 'Статус';

  // ── Admin: Actions ──────────────────────────────────────
  String get editAction => _locale == AppLocale.tatar ? 'Үзгәртү' : 'Редактировать';
  String get deleteAction => _locale == AppLocale.tatar ? 'Бетерү' : 'Удалить';
  String get saveAction => _locale == AppLocale.tatar ? 'Сакларга' : 'Сохранить';
  String get cancelAction => _locale == AppLocale.tatar ? 'Баш тарту' : 'Отмена';
  String get discardChanges => _locale == AppLocale.tatar ? 'Сакламый чыгырга' : 'Выйти без сохранения';
  String get leaveWithoutSaving => _locale == AppLocale.tatar ? 'Сакламый чыгырга' : 'Выйти без сохранения';

  // ── Admin: Forms ────────────────────────────────────────
  String get metadata => _locale == AppLocale.tatar ? 'Мәгълүматлар' : 'Метаданные';
  String get titleField => _locale == AppLocale.tatar ? 'Исем' : 'Заголовок';
  String get enterTitle => _locale == AppLocale.tatar ? 'Исем керү' : 'Введите заголовок';
  String get photoTitleOptional => _locale == AppLocale.tatar
      ? 'Җибәрегез буша — файл исеме куелачак'
      : 'Можно оставить пустым — подставится имя файла';
  String get iconField => _locale == AppLocale.tatar ? 'Иконка *' : 'Иконка *';
  String get selectIcon => _locale == AppLocale.tatar ? 'Иконка сайлагыз' : 'Выберите иконку';
  String get primarySection => _locale == AppLocale.tatar ? 'Төп бүлек (мәҗбүри)' : 'Основной раздел (обязательно)';
  String get selectPrimarySection => _locale == AppLocale.tatar ? 'Төп бүлекне сайлагыз' : 'Выберите основной раздел';
  String get additionalSections => _locale == AppLocale.tatar ? 'Өстәмә бүлекләр' : 'Дополнительные разделы';
  String get enableAdditionalSections => _locale == AppLocale.tatar
      ? 'Өстәмә бүлекләрдә күрсәтергә'
      : 'Показывать в дополнительных разделах';
  String get enableAdditionalSectionsHint => _locale == AppLocale.tatar
      ? 'Сүндерелсә, басма тик төп бүлектә күрсәтеләчәк'
      : 'Если выключено, публикация будет отображаться только в основном разделе';
  String get publishDate => _locale == AppLocale.tatar ? 'Басылу датасы' : 'Дата публикации';
  String get contentBlocks => _locale == AppLocale.tatar ? 'Эчтәлек блоклары' : 'Блоки контента';
  String get addBlock => _locale == AppLocale.tatar ? 'Блок өстәү' : 'Добавить блок';
  String get addFirstBlock => _locale == AppLocale.tatar ? 'Беренче блокны өстәү' : 'Добавьте первый блок контента';

  // ── Admin: Block Types ──────────────────────────────────
  String get textBlock => 'Текст';
  String get textBlockLabel => _locale == AppLocale.tatar ? 'Текстлы блок' : 'Текстовый блок';
  String get imageBlock => _locale == AppLocale.tatar ? 'Рәсем' : 'Изображение';
  String get videoBlock => 'Видео';
  String get audioBlock => 'Аудио';
  String get enterTextHint => _locale == AppLocale.tatar ? 'Текст керү...' : 'Введите текст...';
  String get videoUrlField => 'URL видео';
  String get platformField => _locale == AppLocale.tatar ? 'Урлык' : 'Платформа';
  String get selectImage => _locale == AppLocale.tatar ? 'Сайларга' : 'Выбрать';
  String get replaceImage => _locale == AppLocale.tatar ? 'Алмаштырырга' : 'Заменить';
  String get photoField => _locale == AppLocale.tatar ? 'Фото' : 'Фотография';
  String get selectPhoto => _locale == AppLocale.tatar ? 'Фотоне сайларга' : 'Выбрать фото';
  String get replacePhoto => _locale == AppLocale.tatar ? 'Фотоне алмаштырырга' : 'Заменить фото';
  String get selectPhotoRequired => _locale == AppLocale.tatar ? 'Фотоне сайлагыз' : 'Выберите фотографию';
  String get newPhotoTooltip => _locale == AppLocale.tatar ? 'Яңа фото басма' : 'Новая фотопубликация';
  String get selectFile => _locale == AppLocale.tatar ? 'Файл сайларга' : 'Выбрать файл';
  String get replaceFile => _locale == AppLocale.tatar ? 'Алмаштырырга' : 'Заменить';

  // ── Admin: Save Progress ────────────────────────────────
  String get saving => _locale == AppLocale.tatar ? 'Саклана...' : 'Сохранение...';
  String get savingMetadata => _locale == AppLocale.tatar ? 'Мәгълүматлар саклана...' : 'Сохранение данных...';
  String get uploadingFiles => _locale == AppLocale.tatar ? 'Файллар төяү...' : 'Загрузка файлов...';
  String get savingSections => _locale == AppLocale.tatar ? 'Бүлекләр саклана...' : 'Сохранение разделов...';
  String get savingBlocks => _locale == AppLocale.tatar ? 'Блоклар саклана...' : 'Сохранение блоков...';
  String get saved => _locale == AppLocale.tatar ? 'Сакланды' : 'Сохранено';
  String get saveError => _locale == AppLocale.tatar ? 'Саклау хатасы' : 'Ошибка сохранения';
  String uploadingFileProgress(int uploaded, int total) =>
      _locale == AppLocale.tatar ? 'Файллар төяү $uploaded/$total...' : 'Загрузка файлов $uploaded/$total...';

  // ── Admin: Confirmation Dialogs ─────────────────────────
  String get deleteConfirmation => _locale == AppLocale.tatar ? 'Бетерүне раслау' : 'Подтверждение удаления';
  String deleteConfirmationMessage(String title) =>
      _locale == AppLocale.tatar ? 'Сез чыннан да "$title" бетерергә телисезме?' : 'Вы уверены, что хотите удалить "$title"?';
  String sectionDeleteConfirmation(String name) =>
      _locale == AppLocale.tatar ? 'Сез чыннан да "$name" бүлеген бетерергә телисезме?' : 'Вы уверены, что хотите удалить раздел "$name"?';
  String get cannotDeleteSection => _locale == AppLocale.tatar ? 'Бетереп булмый' : 'Нельзя удалить';
  String sectionHasPublications(String name) => _locale == AppLocale.tatar
      ? '"$name" бүлегендә башмалар бар.\n\nБашмаларны башка бүлеккә күчерегез яки бетерәлгез.'
      : 'Раздел "$name" содержит публикации.\n\nСначала переместите публикации в другой раздел или удалите их.';
  String get gotIt => _locale == AppLocale.tatar ? 'Аңладым' : 'Понятно';

  // ── Admin: Unsaved Changes ──────────────────────────────
  String get unsavedChanges => _locale == AppLocale.tatar ? 'Сакланмаган үзгәрешләр' : 'Несохранённые изменения';
  String get unsavedChangesMessage => _locale == AppLocale.tatar
      ? 'Сакланмаган үзгәрешләр бар. Нәрсә эшләргә киләсе?'
      : 'У вас есть несохранённые изменения. Что вы хотите сделать?';

  // ── Admin: Section Management ───────────────────────────
  String get sectionName => _locale == AppLocale.tatar ? 'Бүлек исеме' : 'Название раздела';
  String get enterSectionName => _locale == AppLocale.tatar ? 'Бүлек исемен керү' : 'Введите название раздела';
  String get showSection => _locale == AppLocale.tatar ? 'Бүлекне күрсәтү' : 'Отображать раздел';
  String get sectionHiddenInfo => _locale == AppLocale.tatar
      ? 'Сүндерелсә, бүлек каталогтан яшерелечәк'
      : 'Если выключено, раздел будет скрыт из каталога';
  String orderLabel(int order) =>
      _locale == AppLocale.tatar ? 'Тәртип: $order' : 'Порядок: $order';
  String get noSections => _locale == AppLocale.tatar ? 'Бүлекләр табылмады' : 'Разделы не найдены';
  String get createFirstSection => _locale == AppLocale.tatar
      ? 'Яңа бүлек булдыру өчен + басыгыз'
      : 'Нажмите + для создания нового раздела';
  String get searchPublications => _locale == AppLocale.tatar ? 'Башмаларны эзләү...' : 'Поиск публикаций...';
  String get noSectionsAvailable => _locale == AppLocale.tatar ? 'Бүлекләр юк' : 'Нет доступных разделов';

  // ── Admin: CRUD Messages ────────────────────────────────
  String get publicationCreated => _locale == AppLocale.tatar ? 'Башма булдырылды' : 'Публикация создана';
  String get publicationUpdated => _locale == AppLocale.tatar ? 'Башма яңартылды' : 'Публикация обновлена';
  String get publicationDeleted => _locale == AppLocale.tatar ? 'Башма бетерелде' : 'Публикация удалена';
  String get sectionSaved => _locale == AppLocale.tatar ? 'Бүлек сакланды' : 'Раздел сохранён';
  String get sectionCreated => _locale == AppLocale.tatar ? 'Бүлек булдырылды' : 'Раздел создан';
  String get sectionDeleted => _locale == AppLocale.tatar ? 'Бүлек бетерелде' : 'Раздел удален';
  String get sectionMovedUp => _locale == AppLocale.tatar ? 'Бүлек югарыга күчерелде' : 'Раздел перемещен вверх';
  String get sectionMovedDown => _locale == AppLocale.tatar ? 'Бүлек аска күчерелде' : 'Раздел перемещен вниз';
  String sectionVisibilityChanged(bool isVisible) =>
      _locale == AppLocale.tatar
          ? (isVisible ? 'Бүлек күрсәтелде' : 'Бүлек яшерелде')
          : (isVisible ? 'Раздел показан' : 'Раздел скрыт');
  String sectionLoadError(String error) =>
      _locale == AppLocale.tatar ? 'Бүлекләрне төяү хатасы: $error' : 'Ошибка загрузки разделов: $error';

  // ── Auth ────────────────────────────────────────────────
  String get email => 'Email';
  String get password => _locale == AppLocale.tatar ? 'Серле сүз' : 'Пароль';
  String get confirmPassword => _locale == AppLocale.tatar ? 'Серле сүзне раслау' : 'Подтвердите пароль';
  String get enterEmail => _locale == AppLocale.tatar ? 'Email керү' : 'Введите email';
  String get enterValidEmail => _locale == AppLocale.tatar ? 'Дөрес email керү' : 'Введите корректный email';
  String get enterPassword => _locale == AppLocale.tatar ? 'Серле сүз керү' : 'Введите пароль';
  String get passwordMinLength => _locale == AppLocale.tatar
      ? 'Серле сүз 6 символдан торырга тиеш'
      : 'Пароль должен содержать минимум 6 символов';
  String get confirmPasswordRequired => _locale == AppLocale.tatar ? 'Серле сүзне раслау' : 'Подтвердите пароль';
  String get passwordsDoNotMatch => _locale == AppLocale.tatar ? 'Серле сүзләр туры килми' : 'Пароли не совпадают';
  String get loginButton => _locale == AppLocale.tatar ? 'Керү' : 'Войти';
  String get registerButton => _locale == AppLocale.tatar ? 'Теркәлү' : 'Зарегистрироваться';
  String get createAccount => _locale == AppLocale.tatar ? 'Аккаунт булдыру' : 'Создать аккаунт';
  String get noAccount => _locale == AppLocale.tatar ? 'Аккаунт юкмы? Теркәлү' : 'Нет аккаунта? Зарегистрироваться';
  String get haveAccount => _locale == AppLocale.tatar ? 'Аккаунтыгыз бармы? Керү' : 'Уже есть аккаунт? Войти';
  String get goHome => _locale == AppLocale.tatar ? 'Баш биткә кайтырга' : 'Вернуться на главную';
  String get noAdminRights => _locale == AppLocale.tatar ? 'Сезнең администратор хокукы юк' : 'У вас нет прав администратора';
  String loginError(String error) =>
      _locale == AppLocale.tatar ? 'Керү хатасы: $error' : 'Ошибка входа: $error';
  String registerError(String error) =>
      _locale == AppLocale.tatar ? 'Теркәлү хатасы: $error' : 'Ошибка регистрации: $error';
  String get userCreated => _locale == AppLocale.tatar ? 'Кулланучы уңышлы булдырылды!' : 'Пользователь успешно создан!';

  // ── Video Widget ────────────────────────────────────────
  String get videoOnRutube => _locale == AppLocale.tatar ? 'Rutube\'да видео' : 'Видео на Rutube';
  String get video => 'Видео';
  String get openInBrowser => _locale == AppLocale.tatar ? 'Браузерда ачу' : 'Открыть в браузере';
  String get videoUnavailable => _locale == AppLocale.tatar ? 'Видео мөмкин түгел' : 'Видео недоступно';
  String get audioUnavailable => _locale == AppLocale.tatar ? 'Аудио мөмкин түгел' : 'Аудио недоступно';
  String couldNotOpenUrl(String url) =>
      _locale == AppLocale.tatar
          ? 'URL ачылмады: $url\nБраузерда кулдан ачыгыз'
          : 'Не удалось открыть URL: $url\nПопробуйте открыть его вручную в браузере';
  String urlOpeningError(String error) =>
      _locale == AppLocale.tatar ? 'URL ачу хатасы: $error' : 'Ошибка при открытии URL: $error';

  // ── About Screen ────────────────────────────────────────
  String get appDescription => _locale == AppLocale.tatar
      ? 'ТАТИСЛАМ — Раил Фәйзрахмановның татар телендәге ислам дәресләре тупланган кушымта. Монда аудио вәгазьләр, видео вәгазьләр һәм мәкаләләр бер урынга җыелган.'
      : 'ТАТИСЛАМ — приложение с исламскими уроками Раиля Файзрахманова на татарском языке. Здесь собраны аудио проповеди, видео проповеди и статьи в одном месте.';
  String get features => _locale == AppLocale.tatar ? 'Кушымта мөмкинлекләре:' : 'Возможности приложения:';
  String get featureAudio => 'Аудио';
  String get featureVideo => 'Видео';
  String get featureArticles => _locale == AppLocale.tatar ? 'Мәкаләләр' : 'Статьи';
  String get featureSearch => _locale == AppLocale.tatar ? 'Эзләү' : 'Поиск';
  String get featureFavorites => _locale == AppLocale.tatar ? 'Сайланганнар' : 'Избранное';
  String get featureFilters => _locale == AppLocale.tatar ? 'Сөзгечләр' : 'Фильтры';
  String get links => _locale == AppLocale.tatar ? 'Сылтамалар:' : 'Ссылки:';
  String get contacts => _locale == AppLocale.tatar ? 'Контактлар:' : 'Контакты:';
  String get linkOurSite => _locale == AppLocale.tatar ? 'Безнең сайт' : 'Наш сайт';
  String get linkYouTube => _locale == AppLocale.tatar ? 'YouTube каналы' : 'YouTube';
  String get linkRuTube => _locale == AppLocale.tatar ? 'RuTube каналы' : 'RuTube';
  String get linkVK => 'ВКонтакте';
  String get linkBip => 'Бип';
  String get linkMax => 'Макс';
  String get linkTelegram => _locale == AppLocale.tatar ? 'Telegram каналы' : 'Telegram';

  // ── Text Scale ──────────────────────────────────────────
  String get textScaleCompact => 'Компактный';
  String get textScaleNormal => 'Обычный';
  String get textScaleLarge => _locale == AppLocale.tatar ? 'Зур' : 'Крупный';
  String get textScaleExtraLarge => _locale == AppLocale.tatar ? 'Бик зур' : 'Очень крупный';

  // ── Video Platform names ────────────────────────────────
  String get youtubeLabel => 'YouTube';
  String get rutubeLabel => 'RuTube';

  // ── Admin: Publication List ────────────────────────────
  String get publicationLoadError => _locale == AppLocale.tatar ? 'Төяү хатасы: ' : 'Ошибка загрузки: ';
  String get selectPublicationIcon => _locale == AppLocale.tatar ? 'Иконка сайлагыз' : 'Выберите иконку публикации';
  String get selectPrimarySectionRequired => _locale == AppLocale.tatar ? 'Төп бүлекне сайлагыз' : 'Выберите основной раздел';
  String get publicationSaveError => _locale == AppLocale.tatar ? 'Саклау хатасы: ' : 'Ошибка сохранения: ';
  String get publicationDeleteError => _locale == AppLocale.tatar ? 'Бетерү хатасы: ' : 'Ошибка удаления: ';

  // ── Admin: Section Editor ──────────────────────────────
  String get sectionLoadErrorT => _locale == AppLocale.tatar ? 'Бүлекне төяү хатасы: ' : 'Ошибка загрузки раздела: ';

  // ── Admin: Section Management ──────────────────────────
  String get sectionVisibilityError => _locale == AppLocale.tatar ? 'Күрсәтүне үзгәртү хатасы: ' : 'Ошибка изменения видимости: ';
  String get sectionDeleteError => _locale == AppLocale.tatar ? 'Бүлекне бетерү хатасы: ' : 'Ошибка удаления раздела: ';
  String get sectionMoveUpError => _locale == AppLocale.tatar ? 'Бүлекне югарыга күчерү хатасы: ' : 'Ошибка перемещения раздела вверх: ';
  String get sectionMoveDownError => _locale == AppLocale.tatar ? 'Бүлекне аска күчерү хатасы: ' : 'Ошибка перемещения раздела вниз: ';

  // ── Admin: Icon selector ───────────────────────────────
  String get selectIconLabel => _locale == AppLocale.tatar ? 'Иконка сайлагыз' : 'Выберите иконку';

  // ── Admin: Publication Editor Errors ───────────────────
  String get publicationLoadErrorDetail => _locale == AppLocale.tatar ? 'Башманы төяү хатасы: ' : 'Ошибка загрузки публикации: ';
  String get fileNotFoundError => _locale == AppLocale.tatar ? 'Файл табылмады' : 'Ошибка: файл не найден';
  String get imageSelectionError => _locale == AppLocale.tatar ? 'Рәсем сайлау хатасы: ' : 'Ошибка выбора изображения: ';

  // ── Misc ────────────────────────────────────────────────
  String get loadMore => _locale == AppLocale.tatar ? 'Тагын төяргә' : 'Загрузить еще';
  String version(String v) => 'v$v';
}