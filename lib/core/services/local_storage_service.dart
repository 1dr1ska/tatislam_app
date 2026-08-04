import 'package:hive_flutter/hive_flutter.dart';

/// Manages all Hive boxes used by the app.
///
/// Each box has a single responsibility:
///
///  - `favorites` — publication id -> true. Source of truth for favorited
///    publications (on-device only, no sync). See [FavoritesRepository].
///  - `settings` — user preferences: text scale, layout mode, audio
///    position, etc. Only simple key-value pairs.
///  - `sections_cache` — cached reference data for sections (JSON array).
///    Allows the UI to bootstrap immediately without network.
///
/// All boxes use only Hive's built-in types (bool, String, List), so no
/// generated adapters or TypeAdapters are required.
class LocalStorageService {
  LocalStorageService._();

  static const String favoritesBoxName = 'favorites';
  static const String settingsBoxName = 'settings';
  static const String sectionsCacheBoxName = 'sections_cache';

  static Box<bool> get favoritesBox => Hive.box<bool>(favoritesBoxName);

  static Box<dynamic> get settingsBox => Hive.box<dynamic>(settingsBoxName);

  static Box<dynamic> get sectionsCacheBox =>
      Hive.box<dynamic>(sectionsCacheBoxName);

  static Future<void> initialize() async {
    await Hive.initFlutter();

    if (!Hive.isBoxOpen(favoritesBoxName)) {
      await Hive.openBox<bool>(favoritesBoxName);
    }
    if (!Hive.isBoxOpen(settingsBoxName)) {
      await Hive.openBox<dynamic>(settingsBoxName);
    }
    if (!Hive.isBoxOpen(sectionsCacheBoxName)) {
      await Hive.openBox<dynamic>(sectionsCacheBoxName);
    }
  }

  static Future<void> close() async {
    for (final name in [
      favoritesBoxName,
      settingsBoxName,
      sectionsCacheBoxName,
    ]) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
    }
  }
}
