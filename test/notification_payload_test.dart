import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/notifications/domain/entities/push_payload.dart';

void main() {
  group('PushPayload.fromData', () {
    test('parses a new_publication message', () {
      final payload = PushPayload.fromData({
        'type': 'new_publication',
        'publication_id': 'pub-1',
        'publication_type': 'article',
        'publication_title': 'Татарская мечеть',
        'publication_photo_path': 'images/abc.png',
      });

      expect(payload.publicationId, 'pub-1');
      expect(payload.publicationType, 'article');
      expect(payload.publicationTitle, 'Татарская мечеть');
      expect(payload.publicationPhotoPath, 'images/abc.png');
    });

    test('photo publications carry the photo path for the fullscreen viewer', () {
      final payload = PushPayload.fromData({
        'type': 'new_publication',
        'publication_id': 'pub-2',
        'publication_type': 'photo',
        'publication_title': 'Фото',
        'publication_photo_path': 'images/xyz.png',
      });

      expect(payload.publicationType, 'photo');
      expect(payload.publicationPhotoPath, 'images/xyz.png');
    });

    test('is empty for messages with a different type', () {
      final payload = PushPayload.fromData({
        'type': 'something_else',
        'publication_id': 'pub-1',
      });

      expect(payload.publicationId, isNull);
    });

    test('is empty when publication_id is missing', () {
      final payload = PushPayload.fromData({
        'type': 'new_publication',
      });

      expect(payload.publicationId, isNull);
      expect(payload.publicationType, isNull);
      expect(payload.publicationTitle, isNull);
    });

    test('tolerates non-string values (FCM data is always strings)', () {
      final payload = PushPayload.fromData({
        'type': 'new_publication',
        'publication_id': 123, // should be ignored
        'publication_title': '',
      });

      expect(payload.publicationId, isNull);
      expect(payload.publicationTitle, isNull);
    });
  });
}