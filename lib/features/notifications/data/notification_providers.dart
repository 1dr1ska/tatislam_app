import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/services/supabase_service.dart';
import 'package:tatislam_app/features/notifications/data/datasources/notification_device_data_source.dart';
import 'package:tatislam_app/features/notifications/services/notification_service.dart';

/// Data source for the `notification_devices` Supabase table.
final notificationDeviceDataSourceProvider =
    Provider<NotificationDeviceDataSource>((ref) {
      return NotificationDeviceDataSource(SupabaseService.client);
    });

/// "Уведомления о новых публикациях" — enabled by default.
///
/// The value is persisted in the Hive `settings` box (same storage as the
/// interface language and text scale), following the existing
/// [Notifier] pattern used by `localeProvider` / `textScaleProvider`.
final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, bool>(
      NotificationSettingsNotifier.new,
    );

class NotificationSettingsNotifier extends Notifier<bool> {
  static const String storageKey = 'notificationsEnabled';

  /// Reads the persisted value directly (used before the provider tree is
  /// mounted, e.g. during `main()` bootstrap).
  static bool readFromStorage() {
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        return box.get(storageKey, defaultValue: true) as bool;
      }
    } catch (_) {
      // Fall through to the default.
    }
    return true;
  }

  @override
  bool build() => readFromStorage();

  /// Persists the choice and keeps the FCM token registration in Supabase in
  /// sync: enabling reactivates the token, disabling deactivates it so the
  /// backend stops sending notifications to this device.
  void setEnabled(bool enabled) {
    state = enabled;
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        box.put(storageKey, enabled);
      }
    } catch (_) {
      // Best-effort persistence.
    }
    // Fire-and-forget: the network call must never block the settings UI.
    unawaited(NotificationService.instance.setEnabled(enabled));
  }
}