import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';

/// Available interface languages.
enum AppLocale {
  tatar(Locale('tt', 'RU'), 'Татарча', 'Татарча'),
  russian(Locale('ru', 'RU'), 'Русский', 'Русский');

  const AppLocale(this.locale, this.displayNameTatar, this.displayNameRussian);

  /// The Flutter [Locale] used by MaterialApp.
  final Locale locale;

  /// Display name in Tatar context.
  final String displayNameTatar;

  /// Display name in Russian context.
  final String displayNameRussian;

  /// Display name in the given locale context.
  String displayName(AppLocale currentLocale) {
    return currentLocale == AppLocale.tatar ? displayNameTatar : displayNameRussian;
  }
}

/// Persists the selected interface language in the settings Hive box.
class LocaleNotifier extends Notifier<AppLocale> {
  static const String _storageKey = 'appLocale';

  @override
  AppLocale build() {
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        final stored = box.get(_storageKey, defaultValue: 'tatar') as String;
        return AppLocale.values.firstWhere(
          (locale) => locale.name == stored,
          orElse: () => AppLocale.tatar,
        );
      }
    } catch (_) {
      // Silently fall through to default
    }
    return AppLocale.tatar;
  }

  void setLocale(AppLocale locale) {
    state = locale;
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        box.put(_storageKey, locale.name);
      }
    } catch (_) {
      // Silently fail — persistence is best-effort
    }
  }
}

/// Global provider for the current interface language.
final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);