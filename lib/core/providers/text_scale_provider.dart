import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';

/// Four text size levels with their respective scale factors.
enum TextScaleLevel {
  standard(1.0),
  large(1.15),
  extraLarge(1.3),
  maximum(1.5);

  const TextScaleLevel(this.scale);

  /// The multiplier applied to base font sizes.
  final double scale;

  /// Display name in Tatar.
  String get displayName {
    return switch (this) {
      TextScaleLevel.standard => 'Стандартный',
      TextScaleLevel.large => 'Крупный',
      TextScaleLevel.extraLarge => 'Очень крупный',
      TextScaleLevel.maximum => 'Максимальный',
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
        final stored = box.get(_storageKey, defaultValue: 'standard') as String;
        return TextScaleLevel.values.firstWhere(
          (level) => level.name == stored,
          orElse: () => TextScaleLevel.standard,
        );
      }
    } catch (_) {
      // Silently fall through to default
    }
    return TextScaleLevel.standard;
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