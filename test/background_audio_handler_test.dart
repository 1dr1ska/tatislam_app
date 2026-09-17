import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tatislam_app/features/audio/data/background_audio_handler.dart';

/// Minimal in-memory player so the handler runs without a platform.
class _FakeAudioPlayer extends AudioPlayer {
  bool _playing = false;
  bool _stopped = false;

  @override
  bool get playing => _playing;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => const Duration(seconds: 60);

  @override
  Stream<PlayerState> get playerStateStream => Stream<PlayerState>.empty();

  @override
  Stream<Duration> get positionStream => Stream<Duration>.empty();

  @override
  Stream<Duration?> get durationStream => Stream<Duration?>.empty();

  @override
  Stream<Duration> get bufferedPositionStream => Stream<Duration>.empty();

  @override
  Future<void> play() async => _playing = true;

  @override
  Future<void> pause() async => _playing = false;

  @override
  Future<void> stop() async {
    _playing = false;
    _stopped = true;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {}
}

void main() {
  late BackgroundAudioHandler handler;
  late _FakeAudioPlayer player;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    BackgroundAudioHandler.enable();
    player = _FakeAudioPlayer();
    handler = BackgroundAudioHandler.instance;
    await handler.attach(player);
  });

  setUp(() {
    // Fresh media item for each test so the assertions are isolated.
    handler.setCurrentMediaItem(
      MediaItem(id: 'b1', title: 'Трек', album: 'Публикация'),
    );
  });

  tearDown(() {
    // Keep the singleton handler clean for the next test.
    handler.setCurrentMediaItem(null);
  });

  group('BackgroundAudioHandler notification removal', () {
    test('attaches the already-known duration to the media item', () {
      expect(handler.mediaItem.value?.duration, const Duration(seconds: 60));
    });

    test('swiping the notification while playing schedules the restore pulse '
        'and does NOT stop the player', () async {
      await player.play();

      final states = <bool>[];
      final sub = handler.playbackState.listen((s) => states.add(s.playing));
      addTearDown(sub.cancel);

      await handler.onNotificationDeleted();

      // The restore pulse immediately publishes a paused edge...
      expect(states.last, isFalse);
      expect(player.playing, isTrue);
      expect(player._stopped, isFalse);

      // ...then (after the short delay) re-activates playback notification.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(states, contains(false));
      expect(states.where((p) => p).isNotEmpty, isTrue);
      expect(player.playing, isTrue);
    });

    test(
      'swiping the notification while paused stops and closes the player',
      () async {
        await player.pause();

        await handler.onNotificationDeleted();

        expect(player.playing, isFalse);
        expect(player._stopped, isTrue);
      },
    );

    test(
      'the advertised actions stay minimal (no stop/skip/rewind buttons)',
      () {
        final state = BackgroundAudioHandler.notificationState(playing: true);

        expect(state.controls, [MediaControl.pause]);
        expect(state.controls, isNot(contains(MediaControl.stop)));
        expect(state.controls, isNot(contains(MediaControl.skipToNext)));
        expect(state.controls, isNot(contains(MediaControl.rewind)));
        expect(state.systemActions, {MediaAction.seek});
      },
    );
  });
}
