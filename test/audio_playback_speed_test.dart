import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_playback_speed_provider.dart';

void main() {
  group('audioSpeedOptions', () {
    test('contains all requested speeds and default 1x', () {
      expect(audioSpeedOptions, [0.5, 0.75, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0]);
      expect(AudioPlaybackSpeedNotifier.defaultSpeed, 1.0);
    });
  });

  group('formatAudioSpeed', () {
    test('formats whole numbers without trailing fraction', () {
      expect(formatAudioSpeed(1.0), '1×');
      expect(formatAudioSpeed(2.0), '2×');
      expect(formatAudioSpeed(0.5), '0.5×');
      expect(formatAudioSpeed(1.1), '1.1×');
      expect(formatAudioSpeed(1.25), '1.25×');
      expect(formatAudioSpeed(1.75), '1.75×');
    });
  });

  group('AudioPlaybackSpeedNotifier persistence', () {
    Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('tatislam_speed_test');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>(LocalStorageService.settingsBoxName);
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk();
    });

    test('setSpeed changes the global value and persists it', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());
      container.read(audioPlaybackSpeedProvider.notifier).setSpeed(1.25);

      expect(container.read(audioPlaybackSpeedProvider), 1.25);
      expect(
        LocalStorageService.settingsBox.get(
          AudioPlaybackSpeedNotifier.storageKey,
        ),
        1.25,
      );
    });

    test(
      'a fresh consumer reads the persisted speed (applied to next track)',
      () {
        // Writer container stores the global speed once.
        final writer = ProviderContainer();
        writer.read(audioPlaybackSpeedProvider.notifier).setSpeed(1.5);
        writer.dispose();

        // A brand-new reader re-reading from storage is exactly what happens when
        // loadTrack() of the shared AudioPlayerService picks up the speed for a
        // newly loaded track.
        final reader = ProviderContainer();
        addTearDown(() => reader.dispose());
        expect(reader.read(audioPlaybackSpeedProvider), 1.5);
      },
    );

    test('rejects speeds outside the supported list', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());
      final notifier = container.read(audioPlaybackSpeedProvider.notifier);
      final before = container.read(audioPlaybackSpeedProvider);

      notifier.setSpeed(0.9);

      // The stored/global value must stay untouched.
      expect(container.read(audioPlaybackSpeedProvider), before);
    });
  });
}
