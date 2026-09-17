import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Prepares the local artwork used by the system media notification.
///
/// `audio_service` resolves `MediaItem.artUri` from `file://`, `http(s)://` or
/// `content://` URIs (asset:// is not supported), so the chosen background is
/// copied once into the app support directory and exposed as [uri].
class AudioArtworkFile {
  AudioArtworkFile._();

  /// Background image used as the notification cover («фон»).
  static const String assetPath = 'assets/images/backgrounds/mountains.png';
  static const String _fileName = 'audio_notification_art.png';

  /// No-op on platforms where [prepare] was never called (web/desktop).
  static Uri? uri;

  /// Copies the artwork asset to a local file. Safe to call more than once.
  /// A failure is cosmetic — playback must never break because of art.
  static Future<void> prepare() async {
    try {
      if (kIsWeb) return;
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File('${dir.path}/$_fileName');
      if (!await file.exists()) {
        final data = await rootBundle.load(assetPath);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      uri = file.uri;
    } catch (e) {
      // Silent — artwork is purely cosmetic.
      uri = null;
    }
  }
}
