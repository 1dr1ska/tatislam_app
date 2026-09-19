import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tatislam_app/features/audio/application/audio_player_service.dart';
import 'package:tatislam_app/features/audio/data/audio_position_store.dart';
import 'package:tatislam_app/features/audio/domain/audio_track.dart';

/// In-memory AudioPositionStore — lets the service logic run without Hive.
class _MemoryPositionStore extends AudioPositionStore {
  final Map<String, int> values = {};

  @override
  int? read(String key) => values[key];

  @override
  void write(String key, int seconds) {
    if (seconds > 0) values[key] = seconds;
  }
}

/// Deterministic stand-in for just_audio's AudioPlayer.
///
/// Overrides only the surface AudioPlayerService touches, so the service logic
/// (track selection, speed application, resume, pause/stop) is fully testable
/// without a real platform/device.
class _FakeAudioPlayer extends AudioPlayer {
  bool _playing = false;
  Duration _position = Duration.zero;
  ProcessingState _processingState = ProcessingState.idle;
  AudioSource? _source;
  double? appliedSpeed;

  void markPosition(Duration position) => _position = position;
  void markCompleted() => _processingState = ProcessingState.completed;

  @override
  bool get playing => _playing;

  @override
  Duration get position => _position;

  @override
  ProcessingState get processingState => _processingState;

  @override
  AudioSource? get audioSource => _source;

  @override
  Future<void> setSpeed(double speed) async {
    appliedSpeed = speed;
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    _source = source;
    _position = initialPosition ?? Duration.zero;
    _processingState = ProcessingState.loading;
    return null;
  }

  @override
  Future<Duration?> load() async {
    _processingState = ProcessingState.ready;
    return null;
  }

  @override
  Future<void> play() async {
    _playing = true;
    _processingState = ProcessingState.ready;
  }

  @override
  Future<void> pause() async {
    _playing = false;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    _position = position ?? Duration.zero;
    _processingState = ProcessingState.ready;
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _position = Duration.zero;
    _source = null;
    _processingState = ProcessingState.idle;
  }
}

void main() {
  group('AudioPlayerService', () {
    late _FakeAudioPlayer player;
    late _MemoryPositionStore store;
    late AudioPlayerService service;
    late List<AudioTrack?> trackChanges;

    AudioTrack track({String id = 'b1'}) => AudioTrack(
      id: id,
      publicationId: 'p1',
      url: 'https://example.com/audio/$id.mp3',
      title: 'Трек $id',
    );

    setUp(() {
      // just_audio's constructor touches AudioSession (interruptions), which
      // requires an initialized Flutter binding even in pure Dart tests.
      WidgetsFlutterBinding.ensureInitialized();
      player = _FakeAudioPlayer();
      store = _MemoryPositionStore();
      trackChanges = [];
      service = AudioPlayerService(
        player: player,
        positionStore: store,
        readSpeed: () => 1.25,
        onCurrentTrackChanged: (track) => trackChanges.add(track),
      );
    });

    test('loadTrack applies the globally saved speed to a new track', () async {
      await service.loadTrack(track());

      expect(player.appliedSpeed, 1.25);
      expect(player.playing, isTrue);
    });

    test('loadTrack exposes the current track to every observer', () async {
      final loaded = track();

      await service.loadTrack(loaded);

      expect(service.currentTrack, loaded);
      expect(service.hasCurrentTrack, isTrue);
      expect(trackChanges.last, loaded);
    });

    test('loadTrack resumes from the saved position', () async {
      store.values['audio_position_p1_b1'] = 42;

      await service.loadTrack(track());

      expect(player.position, Duration(seconds: 42));
    });

    test('loading another URL replaces the current track', () async {
      await service.loadTrack(track(id: 'b1'));
      await service.loadTrack(track(id: 'b2'));

      expect(service.currentTrack?.id, 'b2');
      expect(trackChanges.last?.id, 'b2');
      expect(player.appliedSpeed, 1.25); // speed re-applied on reload
    });

    test('switching tracks saves the previous track resume position', () async {
      await service.loadTrack(track(id: 'b1'));
      player.markPosition(Duration(seconds: 33));

      await service.loadTrack(track(id: 'b2'));

      expect(store.values['audio_position_p1_b1'], 33);
      expect(store.values['audio_position_p1_b2'], isNull);
    });

    test(
      'reloading the same track does not touch its stored position',
      () async {
        store.values['audio_position_p1_b1'] = 12;
        await service.loadTrack(track());
        player.markPosition(Duration(seconds: 33));

        await service.loadTrack(track());

        // Same item → the outgoing-save guard must not fire.
        expect(store.values['audio_position_p1_b1'], 12);
      },
    );

    test(
      'reloading the same source after completion restarts from zero',
      () async {
        await service.loadTrack(track());
        player.markPosition(Duration(seconds: 50));
        player.markCompleted();

        await service.loadTrack(track());

        expect(player.position, Duration.zero);
        expect(player.playing, isTrue);
      },
    );

    test('pause persists the resume position for the current track', () async {
      await service.loadTrack(track());
      player.markPosition(Duration(seconds: 30));

      await service.pause();

      expect(store.values['audio_position_p1_b1'], 30);
      expect(player.playing, isFalse);
    });

    test(
      'toggleCurrent pauses while playing and resumes while paused',
      () async {
        await service.loadTrack(track());
        expect(player.playing, isTrue);

        await service.toggleCurrent();
        expect(player.playing, isFalse);

        await service.toggleCurrent();
        expect(player.playing, isTrue);
      },
    );

    test(
      'stop hides the current track, resets the player and the observer',
      () async {
        await service.loadTrack(track());

        await service.stop();

        expect(service.currentTrack, isNull);
        expect(service.hasCurrentTrack, isFalse);
        expect(trackChanges.last, isNull);
        expect(player.playing, isFalse);
        expect(player.position, Duration.zero);
      },
    );

    test(
      'stop persists the resume position before resetting the player',
      () async {
        await service.loadTrack(track());
        player.markPosition(const Duration(seconds: 77));

        await service.stop();

        // The position at the moment of "close" (X) must be saved so the next
        // launch resumes from there, not from zero.
        expect(store.values['audio_position_p1_b1'], 77);
        expect(service.currentTrack, isNull);
      },
    );

    test('seek moves the shared player', () async {
      await service.loadTrack(track());

      await service.seek(Duration(seconds: 15));

      expect(player.position, Duration(seconds: 15));
    });

    test('play/seek on an empty player are safe no-ops', () async {
      await service.play();
      await service.seek(Duration(seconds: 10));

      // No track got attached and no exception escaped.
      expect(service.hasCurrentTrack, isFalse);
      expect(service.currentTrack, isNull);
    });
  });
}
