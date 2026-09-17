import 'package:tatislam_app/core/services/local_storage_service.dart';

/// Persists per-track playback positions in the app settings Hive box.
///
/// Extracted from the audio widget so the resume-point logic is independent of
/// any UI and can be unit tested without a device.
class AudioPositionStore {
  const AudioPositionStore();

  /// Seconds saved under [key], or null when nothing meaningful is stored.
  int? read(String key) {
    try {
      final box = LocalStorageService.settingsBox;
      if (!box.isOpen) return null;
      final raw = box.get(key);
      return raw is int ? raw : null;
    } catch (_) {
      return null;
    }
  }

  /// Persists [seconds] under [key], ignoring empty/invalid values.
  void write(String key, int seconds) {
    if (seconds <= 0) return;
    try {
      final box = LocalStorageService.settingsBox;
      if (!box.isOpen) return;
      box.put(key, seconds);
    } catch (_) {
      // Best-effort persistence — playback must never break because of it.
    }
  }
}
