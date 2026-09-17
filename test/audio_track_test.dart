import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/audio/data/audio_artwork_file.dart';
import 'package:tatislam_app/features/audio/domain/audio_track.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';

void main() {
  group('AudioTrack', () {
    final track = AudioTrack(
      id: 'b1',
      publicationId: 'p1',
      url: 'https://example.com/audio/track.mp3',
      title: 'Татарская песня',
      subtitle: 'Публикация от 1 января',
      source: AudioSourceType.external,
    );

    test('positionKey is stable and unique per block', () {
      expect(track.positionKey, 'audio_position_p1_b1');
    });

    test('toMediaItem carries the metadata for the media notification', () {
      final item = track.toMediaItem();

      expect(item.id, 'b1');
      expect(item.title, 'Татарская песня');
      expect(item.album, 'Публикация от 1 января');
      expect(item.artUri, isNull);
    });

    test('toMediaItem attaches the notification artwork once prepared', () {
      AudioArtworkFile.uri = Uri.file('/tmp/audio_notification_art.png');
      addTearDown(() => AudioArtworkFile.uri = null);

      final item = track.toMediaItem();

      expect(item.artUri, Uri.file('/tmp/audio_notification_art.png'));
    });

    test('fileName comes from the URL when no upload path is set', () {
      expect(track.fileName, 'track.mp3');
    });

    test(
      'fileName falls back to a safe default without a usable extension',
      () {
        final noName = track.copyWith(url: 'https://example.com/stream');
        expect(noName.fileName, 'audio.mp3');
      },
    );

    test('equality is value-based, not identity-based', () {
      final twin = AudioTrack(
        id: 'b1',
        publicationId: 'p1',
        url: 'https://example.com/audio/track.mp3',
        title: 'Татарская песня',
        subtitle: 'Публикация от 1 января',
        source: AudioSourceType.external,
      );

      expect(track, twin);
      expect(track == twin, isTrue);
    });

    test('is different when the url or id changes', () {
      expect(
        track == track.copyWith(url: 'https://example.com/other.mp3'),
        isFalse,
      );
      expect(track == track.copyWith(id: 'b2'), isFalse);
    });
  });
}
