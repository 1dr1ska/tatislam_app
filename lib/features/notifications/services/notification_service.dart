import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/core/services/supabase_service.dart';
import 'package:tatislam_app/features/notifications/data/datasources/notification_device_data_source.dart';
import 'package:tatislam_app/features/notifications/data/notification_providers.dart';
import 'package:tatislam_app/features/notifications/domain/entities/push_payload.dart';

/// Coordinates the Firebase Cloud Messaging life-cycle for the app.
///
/// Firebase credentials never live here — they stay on the backend
/// (Supabase Edge Function). This service only:
///
///  1. requests notification permission (iOS + Android 13+) once per device,
///  2. keeps `notification_devices` in Supabase in sync with the in-app
///     "notifications enabled" setting (enabled ⇄ `is_active = true`),
///  3. routes push taps to the publication detail screen through the existing
///     go_router setup (`/publication/:id`),
///  4. re-subscribes when the FCM token rotates.
///
/// Initialization is safe to skip: on unsupported platforms (web/desktop) or
/// when Firebase is not configured yet, every method is a clean no-op.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// Local cache of the last token seen — used to deactivate the device when
  /// notifications are switched off *before* FCM returns a fresh token.
  static const String tokenStorageKey = 'fcmToken';

  final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<PushPayload> _tapController =
      StreamController<PushPayload>.broadcast();

  /// Emitted for foreground messages (the OS suppresses the system banner in
  /// the foreground, so the app shows its own glass banner).
  Stream<RemoteMessage> get foregroundMessages =>
      _foregroundController.stream;

  /// Emitted when the user taps a push while the app is backgrounded.
  Stream<PushPayload> get publicationTapEvents => _tapController.stream;

  PushPayload? _pendingInitialTap;
  bool _initialized = false;

  /// FCM is supported on Android and iOS; on web/desktop nothing is set up.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Consumes the tap that woke the app from a terminated state (available
  /// only once, after `initialize()` reads `getInitialMessage()`).
  PushPayload? takePendingInitialTap() {
    final pending = _pendingInitialTap;
    _pendingInitialTap = null;
    return pending;
  }

  /// Must be called once after `Firebase.initializeApp()`.
  Future<void> initialize() async {
    if (_initialized || !isSupported) return;

    final messaging = FirebaseMessaging.instance;

    // Token rotation (Firebase regenerates tokens periodically).
    messaging.onTokenRefresh.listen(_registerToken);

    // Foreground: no system notification is shown — forward to the in-app
    // banner, but only while the user hasn't disabled notifications.
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] != 'new_publication') return;
      if (!NotificationSettingsNotifier.readFromStorage()) return;
      _foregroundController.add(message);
    });

    // Background: user tapped the notification → route to the detail screen.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = PushPayload.fromData(message.data);
      if (payload.publicationId != null) {
        _tapController.add(payload);
      }
    });

    // Terminated: remember the tap until the router is available.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final payload = PushPayload.fromData(initialMessage.data);
      if (payload.publicationId != null) {
        _pendingInitialTap = payload;
      }
    }

    // Register the current token (or deactivate the stored one when the user
    // disabled notifications).
    await syncRegistration();

    _initialized = true;
  }
/// Called by the settings switch. [enabled] is already persisted; this only
  /// syncs the device token state in Supabase.
  Future<void> setEnabled(bool enabled) async {
    if (!isSupported) return;
    try {
      if (enabled) {
        final token = await _requestToken();
        if (token == null) return;
        await _storeToken(token, active: true);
      } else {
        final token = _lastKnownToken();
        _lastToken = null;
        if (token == null) return;
        await _storeToken(token, active: false);
      }
    } catch (e) {
      debugPrint('NotificationService.setEnabled failed: $e');
    }
  }

  /// Registers the current token at startup / on token refresh.
  Future<void> syncRegistration() async {
    if (!isSupported) return;
    try {
      if (NotificationSettingsNotifier.readFromStorage()) {
        final token = await _requestToken();
        if (token == null) return;
        await _storeToken(token, active: true);
      } else {
        final token = _lastKnownToken();
        if (token == null) return;
        await _storeToken(token, active: false);
      }
    } catch (e) {
      debugPrint('NotificationService.syncRegistration failed: $e');
    }
  }

  String? _lastToken;

  Future<String?> _requestToken() async {
    // No-op (returns current status without prompting again) when permission
    // was already granted/denied at the OS level.
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final token = await FirebaseMessaging.instance.getToken();
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<void> _registerToken(String token) async {
    if (!isSupported) return;
    await _storeToken(
      token,
      active: NotificationSettingsNotifier.readFromStorage(),
    );
  }

  String? _lastKnownToken() {
    if (_lastToken != null) return _lastToken;
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        return box.get(tokenStorageKey) as String?;
      }
    } catch (_) {
      // Fall through.
    }
    return null;
  }

  Future<void> _storeToken(String token, {required bool active}) async {
    _lastToken = token;
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        box.put(tokenStorageKey, token);
      }
    } catch (_) {
      // Best-effort cache.
    }

    try {
      await NotificationDeviceDataSource(
        SupabaseService.client,
      ).upsertDevice(fcmToken: token, platform: _platformName, isActive: active);
    } catch (e) {
      debugPrint('NotificationService device upsert failed: $e');
    }
  }

  String get _platformName {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }
}