import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/notifications/data/datasources/notification_device_data_source.dart';

void main() {
  group('NotificationDeviceDataSource.buildRpcParams', () {
    test('builds the register RPC params for an active device', () {
      final params = NotificationDeviceDataSource.buildRpcParams(
        fcmToken: 'fcm-token-for-device-1',
        platform: 'android',
        isActive: true,
      );

      expect(params['p_fcm_token'], 'fcm-token-for-device-1');
      expect(params['p_platform'], 'android');
      expect(params['p_is_active'], true);
    });

    test('builds the register RPC params for a deactivated device', () {
      final params = NotificationDeviceDataSource.buildRpcParams(
        fcmToken: 'fcm-token-for-device-1',
        platform: 'ios',
        isActive: false,
      );

      expect(params['p_fcm_token'], 'fcm-token-for-device-1');
      expect(params['p_platform'], 'ios');
      expect(params['p_is_active'], false);
    });

    test('the same token always produces the same upsert key', () {
      final first = NotificationDeviceDataSource.buildRpcParams(
        fcmToken: 'same-token',
        platform: 'android',
        isActive: true,
      );
      final second = NotificationDeviceDataSource.buildRpcParams(
        fcmToken: 'same-token',
        platform: 'android',
        isActive: false,
      );

      // Upsert keyed on p_fcm_token only — never duplicates a device row.
      expect(first['p_fcm_token'], second['p_fcm_token']);
      expect(first['p_is_active'], isNot(second['p_is_active']));
    });
  });
}