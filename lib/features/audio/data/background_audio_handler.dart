import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:just_audio/just_audio.dart'
    show AudioPlayer, PlayerState, ProcessingState;

/// Bridge to the native media-notification watcher (see MediaListenerService).
const MethodChannel _mediaNotificationChannel = MethodChannel(
  'tatislam/notification',
);

/// Bridges the single shared just_audio player to the system media session
/// (Android notification / iOS Control Center & lock screen).
///
/// Unlike `just_audio_background` this handler controls exactly which action
/// buttons the system shows: **only Play/Pause + a seek timeline**. No fake
/// Previous/Next, no Stop «square», no rewind/forward «circles» — the buttons
/// that confused users. Icons themselves are drawn by the OS from the action
/// we advertise, so the notification shows standard, recognizable glyphs.
///
/// Closing rules:
///  - while audio is PLAYING a removal attempt (swipe / cancel) re-posts the
///    notification — the player cannot be closed from the notification;
///  - while PAUSED a removal stops playback and hides the Mini Player.
class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  BackgroundAudioHandler._();

  static BackgroundAudioHandler? _instance;
  static bool _supported = false;

  /// Whether the handler is wired up (true after [enable] on Android/iOS).
  static bool get supported => _supported;

  /// The app-wide instance used both by `AudioService.init` and the shared
  /// player wiring.
  static BackgroundAudioHandler get instance {
    _instance ??= BackgroundAudioHandler._();
    return _instance!;
  }

  /// Marks the handler as active. Called from `main()` right after
  /// `AudioService.init`, before any AudioPlayer is created.
  static void enable() {
    _supported = true;
  }

  /// The exact `PlaybackState` this handler advertises to the system for a
  /// single-track player. Kept pure so the notification button set is unit
  /// testable without a device.
  ///
  /// Deliberately minimal: only Play/Pause + a seek timeline. No stop button,
  /// no skip next/previous, no rewind/forward circles.
  static PlaybackState notificationState({
    required bool playing,
    AudioProcessingState processingState = AudioProcessingState.ready,
    Duration position = Duration.zero,
    Duration bufferedPosition = Duration.zero,
  }) => PlaybackState(
    playing: playing,
    processingState: processingState,
    controls: [playing ? MediaControl.pause : MediaControl.play],
    androidCompactActionIndices: [0],
    systemActions: const {MediaAction.seek},
    updatePosition: position,
    bufferedPosition: bufferedPosition,
  );

  final Completer<AudioPlayer> _player = Completer<AudioPlayer>();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AudioPlayer? _attachedPlayer;
  MediaItem? _mediaItem;

  // Throttles the position/buffered/state broadcasts: just_audio emits these
  // continuously while playing, and blasting Android with state updates every
  // tick can make the notification's seek bar flicker or vanish.
  int? _lastPositionSeconds;
  int? _lastBufferedSeconds;
  bool? _lastPlaying;
  AudioProcessingState? _lastProcessingState;

  // Android 13+ lets the user swipe the media notification away (no API to
  // block the gesture). While audio is actually playing we keep a heartbeat
  // that re-publishes the state with CHANGING content, so a dismissed
  // notification reappears within a few seconds and playback is never
  // interrupted. Varying content matters: Android's flood protection swallows
  // identical updates to a notification the user just dismissed, but a
  // genuinely new notification (changed extras) is re-posted.
  Timer? _keepAliveTicker;
  static final Duration _keepAliveInterval = Duration(seconds: 6);
  int _keepAliveTick = 0;

  /// Connects the shared player: after this, player events drive the media
  /// session. Idempotent — call it once per player; later calls (e.g. after a
  /// hot restart re-attaching the same shared player) are ignored.
  Future<void> attach(AudioPlayer player) async {
    if (!supported || _attachedPlayer != null) return;
    _attachedPlayer = player;
    _subscriptions.add(player.playerStateStream.listen(_onPlayerState));
    _subscriptions.add(player.positionStream.listen(_onPosition));
    _subscriptions.add(player.durationStream.listen(_onDuration));
    _subscriptions.add(player.bufferedPositionStream.listen(_onBuffered));
    _player.complete(player);
  }

  /// Called by `AudioPlayerService` whenever the current track changes.
  void setCurrentMediaItem(MediaItem? mediaItem) {
    if (!supported || identical(mediaItem, _mediaItem)) return;
    _mediaItem = mediaItem;
    // Reset throttling for the new track so a fresh full state is broadcast.
    _lastPositionSeconds = null;
    _lastBufferedSeconds = null;
    _lastPlaying = null;
    _lastProcessingState = null;
    if (mediaItem == null) {
      queue.add(<MediaItem>[]);
      this.mediaItem.add(null);
    } else {
      // The Android seek bar only appears once the media item has a duration:
      // if the player already knows it (fast local metadata), attach it at once
      // instead of waiting for the duration event.
      var item = mediaItem;
      final knownDuration = _attachedPlayer?.duration;
      if (knownDuration != null) {
        item = item.copyWith(duration: knownDuration);
      }
      _mediaItem = item;
      queue.add(<MediaItem>[item]);
      this.mediaItem.add(item);
    }
    _broadcastState();
  }

  @override
  Future<void> play() async => (await _player.future).play();

  @override
  Future<void> pause() async => (await _player.future).pause();

  @override
  Future<void> seek(Duration position) async =>
      (await _player.future).seek(position);

  @override
  Future<void> stop() async {
    // The media notification must not be closable while audio is playing.
    // Android 13+ lets users swipe media notifications away; if that happens
    // (or the old cancel "X" button is used) we simply re-post the media item
    // so the notification reappears and playback keeps running.
    if (_attachedPlayer?.playing ?? false) {
      final item = _mediaItem;
      if (item != null) {
        mediaItem.add(item);
      }
      return;
    }
    _keepAliveTicker?.cancel();
    _keepAliveTicker = null;
    playbackState.add(
      BackgroundAudioHandler.notificationState(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
    final player = (await _player.future);
    try {
      await player.stop();
    } catch (_) {
      // Player may already be idle.
    }
  }

  @override
  Future<void> onNotificationDeleted() async {
    // Called when the system removed the notification (swipe / clear / X).
    //  - audio playing → restore via a fresh foreground cycle (see
    //    restoreNotification) — playback is never interrupted;
    //  - paused → close the player, which also hides the Mini Player.
    debugPrint(
      'BackgroundAudioHandler.onNotificationDeleted '
      '(playing: ${_attachedPlayer?.playing ?? false})',
    );
    await restoreNotification();
    if (!(_attachedPlayer?.playing ?? false)) {
      await stop();
    }
  }

  void _broadcastState() {
    if (_mediaItem == null) {
      playbackState.add(
        BackgroundAudioHandler.notificationState(
          playing: false,
          processingState: AudioProcessingState.idle,
        ),
      );
    } else {
      playbackState.add(
        BackgroundAudioHandler.notificationState(playing: false),
      );
    }
  }

  void _onPlayerState(PlayerState state) {
    if (!supported) return;
    final processingState = _mapProcessing(state.processingState);
    if (state.playing == _lastPlaying &&
        identical(processingState, _lastProcessingState)) {
      return;
    }
    _lastPlaying = state.playing;
    _lastProcessingState = processingState;
    _updateKeepAliveTicker();
    playbackState.add(
      BackgroundAudioHandler.notificationState(
        playing: state.playing,
        processingState: processingState,
      ),
    );
  }

  Future<void> restoreNotification() async {
    if (!supported || !(_attachedPlayer?.playing ?? false)) return;
    // Force a fresh foreground notification cycle. audio_service only calls
    // the Android plugin's enterPlayingState() (which START-FOREGROUNDs a new,
    // re-shown notification) on a playing:false → playing:true rising edge.
    // A plain updateNotification() does NOT bring back a dismissed card.
    playbackState.add(
      BackgroundAudioHandler.notificationState(
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );
    _keepAliveTicker?.cancel();
    _keepAliveTicker = null;
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!supported || !(_attachedPlayer?.playing ?? false)) return;
      _broadcastState();
      playbackState.add(
        BackgroundAudioHandler.notificationState(
          playing: true,
          processingState: AudioProcessingState.ready,
        ),
      );
      _updateKeepAliveTicker();
    });
  }

  /// Keeps the native watcher's «is playing» flag in sync so it can decide to
  /// restore the notification when the system removes it.
  Future<void> _publishPlayingFlag(bool playing) async {
    try {
      await _mediaNotificationChannel.invokeMethod('setPlaying', {
        'playing': playing,
      });
    } catch (_) {
      // Channel/missing platform — best effort only.
    }
  }

  /// Starts/stops the heartbeat that re-posts a swiped notification while the
  /// audio is running, and keeps the native watcher's «is playing» flag in sync.
  void _updateKeepAliveTicker() {
    final playing = _attachedPlayer?.playing ?? false;
    _publishPlayingFlag(playing);
    if (playing && _keepAliveTicker == null) {
      _keepAliveTicker = Timer.periodic(_keepAliveInterval, (_) {
        _keepAlive();
      });
    } else if (!playing && _keepAliveTicker != null) {
      _keepAliveTicker?.cancel();
      _keepAliveTicker = null;
    }
  }

  void _keepAlive() {
    if (!supported) return;
    final item = _mediaItem;
    if (item != null) {
      _keepAliveTick++;
      // Re-publish with a *changing* extras value: identical content is
      // swallowed as a flood-protected duplicate right after a swipe, while a
      // changed notification is treated as new and re-shown by the system.
      mediaItem.add(item.copyWith(extras: {'keepAlive': _keepAliveTick}));
    }
    // A fresh PlaybackState forces audio_service to re-post the notification
    // even if every visible value is unchanged.
    playbackState.add(
      playbackState.value.copyWith(speed: playbackState.value.speed),
    );
  }

  void _onPosition(Duration position) {
    if (!supported) return;
    final seconds = position.inSeconds;
    if (seconds == _lastPositionSeconds) return;
    _lastPositionSeconds = seconds;
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  void _onBuffered(Duration bufferedPosition) {
    if (!supported) return;
    final seconds = bufferedPosition.inSeconds;
    if (seconds == _lastBufferedSeconds) return;
    _lastBufferedSeconds = seconds;
    playbackState.add(
      playbackState.value.copyWith(bufferedPosition: bufferedPosition),
    );
  }

  void _onDuration(Duration? duration) {
    if (!supported || _mediaItem == null || duration == null) return;
    // The Android seek bar only appears once the media item has a duration.
    _mediaItem = _mediaItem!.copyWith(duration: duration);
    mediaItem.add(_mediaItem);
    queue.add(queue.value..replaceRange(0, 1, [_mediaItem!]));
  }

  AudioProcessingState _mapProcessing(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }
}
