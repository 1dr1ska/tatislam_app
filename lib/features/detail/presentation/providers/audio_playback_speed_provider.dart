import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';

/// Playback speed choices shared by all audio UI.
const List<double> audioSpeedOptions = [
  0.5,
  0.75,
  1.0,
  1.1,
  1.25,
  1.5,
  1.75,
  2.0,
];

/// Human-readable speed label, e.g. `1.25` → `1.25×`.
String formatAudioSpeed(double speed) {
  final normalized = speed == speed.roundToDouble()
      ? speed.round().toString()
      : '$speed';
  return '$normalized×';
}

/// Full-control notifier that keeps ONE global playback speed for the whole
/// app (not per-audio). Persisted in the settings Hive box and immediately
/// applied to the shared [audioPlayerProvider] so already-playing audio
/// switches speed right away.
class AudioPlaybackSpeedNotifier extends Notifier<double> {
  static const String storageKey = 'audioPlaybackSpeed';
  static const double defaultSpeed = 1.0;

  @override
  double build() {
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        final stored = box.get(storageKey, defaultValue: defaultSpeed);
        final value = double.tryParse(stored.toString());
        if (value != null && audioSpeedOptions.contains(value)) {
          return value;
        }
      }
    } catch (_) {
      // Silently fall through to the default.
    }
    return defaultSpeed;
  }

  /// Sets a new global speed, persists it and immediately closes the loop with
  /// the running playback: the shared [AudioPlayerService] listens to this
  /// provider and applies the change to the currently loaded track right away
  /// (see `audioPlayerServiceProvider`). New tracks apply the value on load.
  void setSpeed(double speed) {
    if (!audioSpeedOptions.contains(speed)) return;
    state = speed;
    try {
      final box = LocalStorageService.settingsBox;
      if (box.isOpen) {
        box.put(storageKey, speed);
      }
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

/// Global provider for the current audio playback speed.
final audioPlaybackSpeedProvider =
    NotifierProvider<AudioPlaybackSpeedNotifier, double>(
      AudioPlaybackSpeedNotifier.new,
    );
