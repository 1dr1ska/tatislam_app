import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to the `notification_devices` Supabase table through the
/// `register_notification_device` RPC.
///
/// The RPC is a security-definer function backed by an `upsert ON CONFLICT`
/// keyed on `fcm_token`, so:
///  - the same device token is never stored twice,
///  - a user may own many devices (one row per token),
///  - disabling notifications simply flips `is_active` to `false` — the row
///    (and therefore the token) is kept for a later re-enable.
///
/// Direct anon/authenticated access to the table is denied by RLS — the only
/// public surface is this parameterised function, which is why no Firebase
/// credentials ever live on the client.
class NotificationDeviceDataSource {
  final SupabaseClient _client;

  NotificationDeviceDataSource(this._client);

  /// Registers (or updates) the device [fcmToken] in Supabase.
  ///
  /// [isActive] reflects the in-app "notifications enabled" setting: `false`
  /// means the backend simply skips this token when broadcasting.
  Future<void> upsertDevice({
    required String fcmToken,
    required String platform,
    required bool isActive,
  }) async {
    await _client.rpc(
      'register_notification_device',
      params: buildRpcParams(
        fcmToken: fcmToken,
        platform: platform,
        isActive: isActive,
      ),
    );
  }

  /// Pure builder — kept separate so the request shape is unit-testable
  /// without a live Supabase client.
  static Map<String, dynamic> buildRpcParams({
    required String fcmToken,
    required String platform,
    required bool isActive,
  }) {
    return {
      'p_fcm_token': fcmToken,
      'p_platform': platform,
      'p_is_active': isActive,
    };
  }
}