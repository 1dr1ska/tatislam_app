import 'package:hive_flutter/hive_flutter.dart';

/// Initializes and exposes the two local (on-device only) Hive boxes the
/// app needs. Both only ever store Hive's built-in types (bool, String),
/// so no generated adapters are required — keeping this intentionally
/// simple, since nothing here needs to survive a schema change.
///
///  - `favorites`: publication id -> true. The source of truth for
///    favorited publications lives on-device only, by design (no account
///    sync); see [FavoritesRepository].
///  - `settings`: small user preferences, e.g. the selected home layout
///    mode (feed vs. cards); see [HomeLayoutPreferenceRepository].
class LocalStorageService {
  LocalStorageService._();

  static const String favoritesBoxName = 'favorites';
  static const String settingsBoxName = 'settings';

  static Box<bool> get favoritesBox => Hive.box<bool>(favoritesBoxName);

  static Box<dynamic> get settingsBox => Hive.box<dynamic>(settingsBoxName);

  static Future<void> initialize() async {
    await Hive.initFlutter();

    if (!Hive.isBoxOpen(favoritesBoxName)) {
      await Hive.openBox<bool>(favoritesBoxName);
    }
    if (!Hive.isBoxOpen(settingsBoxName)) {
      await Hive.openBox<dynamic>(settingsBoxName);
    }
  }

  static Future<void> close() async {
    if (Hive.isBoxOpen(favoritesBoxName)) {
      await Hive.box(favoritesBoxName).close();
    }
    if (Hive.isBoxOpen(settingsBoxName)) {
      await Hive.box(settingsBoxName).close();
    }
  }
}
