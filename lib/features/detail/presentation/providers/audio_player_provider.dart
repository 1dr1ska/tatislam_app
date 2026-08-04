import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Manages the lifecycle of an [AudioPlayer].
///
/// Kept alive across screen transitions to preserve playback state
/// (source, position, speed) when navigating away and back.
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() {
    player.dispose();
  });
  // Keep alive – the player should not be disposed when no widget
  // is watching it, otherwise state (position, source) is lost.
  ref.keepAlive();
  return player;
});
