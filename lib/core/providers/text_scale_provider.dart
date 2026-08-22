import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/providers/locale_provider.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';

/// Four text size levels with their respective scale factors.
enum TextScaleLevel {
  compact(1.0),
  normal(1.15),
  large(1.3),
  extraLarge(1.5);

  const TextScaleLevel(this.scale);

  /// The multiplier applied to base font sizes.
  final double scale;

  /// Display name localized for the given locale.
  String displayName(AppLocale locale) {
    return switch (this) {
      TextScaleLevel.compact => locale == AppLocale.tatar ? 'Компакт' : 'Компактный',
      TextScaleLevel.normal => locale == AppLocale.tatar ? 'Гадәти' : 'Обычный',
      TextScaleLevel.large => locale == AppLocale.tatar ? 'Зур' : 'Крупный',
      TextScaleLevel.extraLarge => locale == AppLocale.tatar ? 'Бик зур' : 'Очень крупный',
    };
  }
}

/// Persists the selected text scale level in the settings Hive box.
class TextScaleNotifier extends Notifier<TextScaleLevel> {
  static const String _storageKey = 'textScaleLevel';

  @override
  TextScaleLevel build() {
    // Read saved value from Hive immediately — Hive is initialized before
    // runApp(), so the box is guaranteed to be open at provider creation time.
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        final stored = box.get(_storageKey, defaultValue: 'normal') as String;
        // Migrate old enum names (standard→compact, large→normal, etc.)
        // to preserve existing user choices after rename.
        return switch (stored) {
          'standard' => TextScaleLevel.compact, // old 1.0 → compact 1.0
          'large' => TextScaleLevel.normal, // old 1.15 → normal 1.15
          'extraLarge' => TextScaleLevel.large, // old 1.3 → large 1.3
          'maximum' => TextScaleLevel.extraLarge, // old 1.5 → extraLarge 1.5
          _ => TextScaleLevel.values.firstWhere(
            (level) => level.name == stored,
            orElse: () => TextScaleLevel.normal,
          ),
        };
      }
    } catch (_) {
      // Silently fall through to default
    }
    return TextScaleLevel.normal;
  }

  void setScale(TextScaleLevel level) {
    state = level;
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        box.put(_storageKey, level.name);
      }
    } catch (_) {
      // Silently fail — persistence is best-effort
    }
  }
}

/// Global provider for the current text scale level.
final textScaleProvider = NotifierProvider<TextScaleNotifier, TextScaleLevel>(
  TextScaleNotifier.new,
);
