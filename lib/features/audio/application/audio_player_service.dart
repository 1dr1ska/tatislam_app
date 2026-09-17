import 'dart:async';
import 'dart:developer' as developer;

import 'package:just_audio/just_audio.dart';
import 'package:tatislam_app/features/audio/data/audio_position_store.dart';
import 'package:tatislam_app/features/audio/domain/audio_track.dart';

/// Single shared source of truth for audio playback.
///
/// Owns the one and only [AudioPlayer] of the app (via [player]) and exposes a
/// small UI-friendly API on top of it. The detail audio block, the Mini Player,
/// the full player screen and the system media session all derive their state
/// from this instance — no second independent player is ever created.
///
/// [readSpeed] lets the service pick up the globally persisted playback speed
/// when a new track is loaded (see `audioPlaybackSpeedProvider`).
/// [onCurrentTrackChanged] is a pure notification hook used by the Riverpod
/// layer to keep `AudioSnapshot` in sync — it keeps this class free of Riverpod
/// imports and therefore unit-testable.
class AudioPlayerService {
  AudioPlayerService({
    required this._player,
    this._positionStore = const AudioPositionStore(),
    this._readSpeed,
    this._onCurrentTrackChanged,
  }) {
    // Persist the position continuously from the position stream (the
    // recommended community pattern): while audio moves, the resume point is
    // saved every second, so even a hard kill of the app loses at most ~1s.
    _positionSub = _player.positionStream.listen(_onPositionTick);
  }

  final AudioPlayer _player;
  final AudioPositionStore _positionStore;
  final double Function()? _readSpeed;
  final void Function(AudioTrack? track)? _onCurrentTrackChanged;

  AudioTrack? _currentTrack;

  // Continuous position persistence (see constructor).
  StreamSubscription<Duration>? _positionSub;
  int _lastSavedSecond = -1;

  // Reentrancy guard: prevents a second loadTrack for the same track from
  // recreating the platform source (Android ExoPlayer churn → jitter).
  bool _loadInFlight = false;

  AudioPlayer get player => _player;

  /// The track currently loaded into the shared player, if any.
  AudioTrack? get currentTrack => _currentTrack;

  bool get hasCurrentTrack => _currentTrack != null;

  // Mirrors the underlying just_audio player.
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  Duration get bufferedPosition => _player.bufferedPosition;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// Loads [track] into the shared player and optionally starts playback.
  ///
  /// Starting playback applies the globally saved playback speed and resumes
  /// from the last saved position of this track (when applicable). Calling it on
  /// an already-completed track restarts from zero.
  Future<bool> loadTrack(AudioTrack track, {bool autoplay = true}) async {
    // Guard against rapid repeated taps (each call would otherwise recreate
    // the platform source on Android: ExoPlayer Init/Release churn resets the
    // position and makes the slider «walk»).
    if (_loadInFlight && _currentTrack?.id == track.id) {
      if (autoplay && !_player.playing) {
        try {
          await _player.play();
        } catch (e) {
          developer.log('AudioPlayerService.loadTrack replay failed', error: e);
        }
      }
      return true;
    }
    _loadInFlight = true;

    try {
      // Persist the outgoing track's position BEFORE switching, otherwise the
      // resume point of the previous audio is silently lost.
      if (_currentTrack != null && _currentTrack!.id != track.id) {
        _savePosition();
      }
      _setTrack(track);

      final currentSource = _player.audioSource;
      final needsReload =
          currentSource is! UriAudioSource ||
          currentSource.uri.toString() != track.url;

      await _player.setSpeed(
        _readSpeed?.call() ?? AudioPlayerService.defaultSpeed,
      );

      final saved = _savedPosition(track);

      if (needsReload) {
        // setAudioSource(preload: true) already loads the source — calling
        // load() again would make Android spin up a second ExoPlayer and tear
        // the first one down (the churn that made the time jump around).
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(track.url), tag: track.toMediaItem()),
          initialPosition: saved,
        );
        // Belt-and-braces restore: `initialPosition` is ignored by some
        // platforms, so re-assert the resume point explicitly.
        if (saved > Duration.zero &&
            _positionDiffSeconds(saved, _player.position) > 1) {
          await _player.seek(saved);
        }
        developer.log(
          'AudioPlayerService.loadTrack ${track.id}: '
          'needsReload=true saved=${saved.inSeconds}s '
          'positionAfter=${_player.position.inSeconds}s',
        );
      } else if (_player.processingState == ProcessingState.completed) {
        // Completed state does not resume on play() — seek back to zero.
        await _player.seek(Duration.zero);
      } else {
        if (saved > Duration.zero &&
            _player.position < const Duration(seconds: 1)) {
          await _player.seek(saved);
        }
      }

      if (autoplay) {
        await _player.play();
      }
      return true;
    } catch (e) {
      developer.log('AudioPlayerService.loadTrack failed', error: e);
      return false;
    } finally {
      _loadInFlight = false;
    }
  }

  static int _positionDiffSeconds(Duration a, Duration b) =>
      (a.inSeconds - b.inSeconds).abs();

  static const double defaultSpeed = 1.0;

  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      developer.log('AudioPlayerService.play failed', error: e);
    }
  }

  Future<void> pause() async {
    _savePosition();
    try {
      await _player.pause();
    } catch (e) {
      developer.log('AudioPlayerService.pause failed', error: e);
    }
  }

  /// Play/pause for the currently loaded track. A completed track restarts.
  Future<void> toggleCurrent() async {
    final track = _currentTrack;
    if (track == null) return;
    if (_player.playing || _player.processingState == ProcessingState.loading) {
      await pause();
      return;
    }
    await loadTrack(track, autoplay: true);
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      developer.log('AudioPlayerService.seek failed', error: e);
    }
  }

  Future<void> applySpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
    } catch (e) {
      developer.log('AudioPlayerService.applySpeed failed', error: e);
    }
  }

  /// Stops playback, resets the position and releases the media session: the
  /// Mini Player hides and the media notification disappears until the next load.
  Future<void> stop() async {
    _savePosition();
    try {
      await _player.stop();
    } catch (e) {
      developer.log('AudioPlayerService.stop failed', error: e);
    }
    _setTrack(null);
  }

  /// Drops the current track without touching the player. Used when the shared
  /// player is stopped externally — e.g. from the system media notification —
  /// so the Mini Player hides in sync.
  void clearTrack() {
    _setTrack(null);
  }

  /// Persists the current position so a later session can resume the same track.
  Future<void> savePosition() async {
    _savePosition();
  }

  /// Cancels the position-persistence subscription. The service is app-lifetime,
  /// so this only runs on teardown / hot restart.
  void dispose() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Continuous saver fed by the player's position stream (see constructor).
  /// This is what keeps the resume point fresh even if the app is killed.
  void _onPositionTick(Duration position) {
    final track = _currentTrack;
    if (track == null) return;
    final seconds = position.inSeconds;
    if (seconds <= 1 || seconds == _lastSavedSecond) return;
    _lastSavedSecond = seconds;
    _positionStore.write(track.positionKey, seconds);
  }

  void _savePosition() {
    final track = _currentTrack;
    if (track == null) return;
    final seconds = _player.position.inSeconds;
    if (seconds > 1) {
      _positionStore.write(track.positionKey, seconds);
      developer.log(
        'AudioPlayerService.savePosition key=${track.positionKey} sec=$seconds',
      );
    }
  }

  Duration _savedPosition(AudioTrack track) {
    final saved = _positionStore.read(track.positionKey);
    return saved == null || saved <= 0
        ? Duration.zero
        : Duration(seconds: saved);
  }

  void _setTrack(AudioTrack? track) {
    _currentTrack = track;
    _lastSavedSecond = -1;
    _onCurrentTrackChanged?.call(track);
  }
}
