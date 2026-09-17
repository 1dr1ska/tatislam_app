import 'package:just_audio/just_audio.dart';
import 'package:tatislam_app/features/audio/domain/audio_track.dart';

/// A single immutable projection of the shared audio player state, rebuilt
/// from the player's event streams. Every audio UI widget (detail block,
/// Mini Player, full player screen) watches this instead of subscribing to
/// the raw player streams directly, which keeps the UI code uniform across
/// the whole app.
class AudioSnapshot {
  const AudioSnapshot({
    this.track,
    this.isPlaying = false,
    this.processingState = ProcessingState.idle,
    this.position = Duration.zero,
    this.duration,
    this.bufferedPosition = Duration.zero,
  });

  /// The track currently loaded into the shared player (null → no track,
  /// Mini Player hidden).
  final AudioTrack? track;

  /// Whether the player is actually outputting audio.
  final bool isPlaying;

  /// just_audio processing state (idle → loading → buffering → ready/completed).
  final ProcessingState processingState;

  final Duration position;
  final Duration? duration;
  final Duration bufferedPosition;

  bool get hasTrack => track != null;
  bool get isCompleted => processingState == ProcessingState.completed;

  AudioSnapshot copyWith({
    AudioTrack? track,
    bool? isPlaying,
    ProcessingState? processingState,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool clearTrack = false,
  }) {
    return AudioSnapshot(
      track: clearTrack ? null : (track ?? this.track),
      isPlaying: isPlaying ?? this.isPlaying,
      processingState: processingState ?? this.processingState,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
    );
  }

  @override
  String toString() =>
      'AudioSnapshot(track: ${track?.id ?? '<none>'}, isPlaying: $isPlaying, '
      'processingState: $processingState, position: $position, duration: $duration)';
}
