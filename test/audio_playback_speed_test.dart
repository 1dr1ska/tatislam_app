import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_playback_speed_provider.dart';

void main() {
  group('audioSpeedOptions', () {
    test('contains all requested speeds and default 1x', () {
      expect(audioSpeedOptions, [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]);
      expect(AudioPlaybackSpeedNotifier.defaultSpeed, 1.0);
    });
  });

  group('formatAudioSpeed', () {
    test('formats whole numbers without trailing fraction', () {
      expect(formatAudioSpeed(1.0), '1×');
      expect(formatAudioSpeed(2.0), '2×');
      expect(formatAudioSpeed(0.5), '0.5×');
      expect(formatAudioSpeed(1.25), '1.25×');
      expect(formatAudioSpeed(1.75), '1.75×');
    });
  });
}