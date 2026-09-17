import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tatislam_app/features/audio/application/audio_player_service.dart';
import 'package:tatislam_app/features/audio/application/audio_snapshot.dart';
import 'package:tatislam_app/features/audio/data/background_audio_handler.dart';
import 'package:tatislam_app/features/audio/domain/audio_track.dart';
import 'package:tatislam_app/features/detail/presentation/providers/audio_playback_speed_provider.dart';

/// The single shared just_audio player.
///
/// Lives in the app-wide audio feature (moved here from the detail feature) so
/// the detail audio block, the Mini Player, the full player screen and the
/// system media session all use ONE player. Kept alive across navigation —
/// playback continues between screens.
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  // Feed the system media session from this exact player (Android/iOS).
  if (BackgroundAudioHandler.supported) {
    unawaited(BackgroundAudioHandler.instance.attach(player));
  }
  ref.onDispose(player.dispose);
  ref.keepAlive();
  return player;
});

/// UI projection of the shared player state.
///
/// A single [AudioSnapshot] notifier is fed by the one shared player's event
/// streams (see [audioPlayerServiceProvider]) and watched by every audio widget.
/// This is not a parallel playback state — it is a read mirror of the player.
class AudioSnapshotNotifier extends Notifier<AudioSnapshot> {
  @override
  AudioSnapshot build() => const AudioSnapshot();

  void setTrack(AudioTrack? track) =>
      state = state.copyWith(track: track, clearTrack: track == null);

  void setPlayerState(PlayerState playerState) => state = state.copyWith(
    isPlaying: playerState.playing,
    processingState: playerState.processingState,
  );

  void setPosition(Duration position) =>
      state = state.copyWith(position: position);

  void setDuration(Duration? duration) =>
      state = state.copyWith(duration: duration);

  void setBuffered(Duration buffered) =>
      state = state.copyWith(bufferedPosition: buffered);
}

final audioSnapshotProvider =
    NotifierProvider<AudioSnapshotNotifier, AudioSnapshot>(
      AudioSnapshotNotifier.new,
    );

/// The single shared playback service — the one place the app drives the
/// player (play/pause/seek/speed/stop) and the entry point for the Mini Player
/// and the full player screen.
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final snapshotNotifier = ref.read(audioSnapshotProvider.notifier);
  final service = AudioPlayerService(
    player: ref.read(audioPlayerProvider),
    readSpeed: () => ref.read(audioPlaybackSpeedProvider),
    onCurrentTrackChanged: (track) {
      snapshotNotifier.setTrack(track);
      // Keep the system media notification in sync with the shared player.
      if (BackgroundAudioHandler.supported) {
        BackgroundAudioHandler.instance.setCurrentMediaItem(
          track?.toMediaItem(),
        );
      }
    },
  );

  // Mirror the shared player's event streams into the UI snapshot so every
  // screen sees exactly the same state.
  ProcessingState? lastProcessingState;
  final subscriptions = <StreamSubscription<dynamic>>[
    service.playerStateStream.listen((state) {
      snapshotNotifier.setPlayerState(state);

      // Persist the resume point when the user pauses from the system media
      // notification / lock screen (i.e. outside the app UI). A completed
      // track must not overwrite the saved position.
      if (!state.playing &&
          state.processingState != ProcessingState.completed &&
          service.hasCurrentTrack) {
        service.savePosition();
      }

      // A stop pressed in the media notification halts the shared player
      // directly (ready -> idle) without going through service.stop() — drop
      // the current track so the Mini Player hides in sync.
      if (service.hasCurrentTrack &&
          state.processingState == ProcessingState.idle &&
          lastProcessingState != null &&
          lastProcessingState != ProcessingState.idle) {
        service.clearTrack();
      }
      lastProcessingState = state.processingState;
    }),
    service.positionStream.listen(snapshotNotifier.setPosition),
    service.durationStream.listen(snapshotNotifier.setDuration),
    service.bufferedPositionStream.listen(snapshotNotifier.setBuffered),
  ];

  // Changing the global speed while audio is loaded applies immediately.
  ref.listen(audioPlaybackSpeedProvider, (previous, next) {
    if (previous != next) {
      service.applySpeed(next);
    }
  });

  ref.onDispose(() {
    service.dispose();
    for (final sub in subscriptions) {
      unawaited(sub.cancel());
    }
  });
  ref.keepAlive();
  return service;
});
