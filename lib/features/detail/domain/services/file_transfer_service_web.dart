import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Browser (web) implementation of the audio transfer service.
///
/// There is no real filesystem on the web, so:
///  - "Save" opens the audio URL in a new tab, letting the browser handle the
///    download;
///  - "Share" hands the public URL to the platform share dialog.
class FileTransferService {
  const FileTransferService();

  Future<FileTransferResult> saveFile({
    required String url,
    String? fileName,
    void Function(int downloaded, int? total)? onProgress,
  }) async {
    onProgress?.call(1, 1);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      return FileTransferResult(
        status: ok ? FileSaveStatus.saved : FileSaveStatus.unavailable,
      );
    } catch (e) {
      return FileTransferResult(
        status: FileSaveStatus.error,
        message: e.toString(),
      );
    }
  }

  Future<FileShareResult> shareFile({
    required String url,
    String? fileName,
    void Function(int progress, int? total)? onProgress,
  }) async {
    onProgress?.call(1, 1);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: url,
          subject: fileName ?? 'Аудио',
        ),
      );
      return FileShareResult(
        shared: result.status != ShareResultStatus.unavailable,
      );
    } catch (e) {
      return FileShareResult(shared: false, error: e.toString());
    }
  }
}

/// Status of a save/download operation.
enum FileSaveStatus { saved, canceled, unavailable, error }

/// Result of a save/download operation.
class FileTransferResult {
  final FileSaveStatus status;
  final String? path;
  final String? message;

  const FileTransferResult({required this.status, this.path, this.message});
}

/// Result of a share operation.
class FileShareResult {
  final bool shared;
  final String? error;

  const FileShareResult({required this.shared, this.error});
}

/// Derives a safe file name from a URL for non-web platforms.
String deriveFileName(String url, {String fallback = 'audio.mp3'}) {
  return fallback;
}