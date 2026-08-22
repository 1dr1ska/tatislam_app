import 'dart:io';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Status of a save/download operation.
enum FileSaveStatus { saved, canceled, unavailable, error }

/// Result of a save/download operation.
class FileTransferResult {
  final FileSaveStatus status;

  /// Path of the saved file when [status] is [FileSaveStatus.saved].
  final String? path;

  /// Human-readable error message when [status] is [FileSaveStatus.error].
  final String? message;

  const FileTransferResult({required this.status, this.path, this.message});
}

/// Result of a share operation.
class FileShareResult {
  final bool shared;
  final String? error;

  const FileShareResult({required this.shared, this.error});
}

/// Derives a safe file name from a URL, falling back to [fallback] when the
/// URL has no usable last path segment.
String deriveFileName(String url, {String fallback = 'audio.mp3'}) {
  try {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final last = segments.last;
      if (last.contains('.')) return last;
    }
  } catch (_) {
    // Fall through.
  }
  return fallback;
}

/// Real filesystem implementation (Android / iOS / desktop).
///
/// Downloads are streamed to disk chunk-by-chunk (never buffered fully in
/// memory), so 30–50 MB audio files stay smooth. Saved files land in a
/// user-visible location chosen via the system "Save as" dialog. Shared files
/// are copied to a temporary path and deleted once the share sheet closes.
class FileTransferService {
  final http.Client _client;

  FileTransferService({http.Client? client}) : _client = client ?? http.Client();

  /// Downloads [url] into the app cache if it isn't already there, then opens
  /// the platform "Save as" dialog so the user can pick a visible location.
  Future<FileTransferResult> saveFile({
    required String url,
    String? fileName,
    void Function(int downloaded, int? total)? onProgress,
  }) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final cacheDirFile = Directory(
        '${cacheDir.path}/audio',
      );
      await cacheDirFile.create(recursive: true);

      final name = fileName ?? deriveFileName(url);
      final cached = File('${cacheDirFile.path}/$name');
      if (!await cached.exists() || await cached.length() == 0) {
        await _downloadToFile(url, cached, onProgress);
      } else {
        onProgress?.call(await cached.length(), await cached.length());
      }

      final result = await _saveFromFile(cached, name);
      return result;
    } catch (e) {
      return FileTransferResult(
        status: FileSaveStatus.error,
        message: e.toString(),
      );
    }
  }

  Future<FileTransferResult> _saveFromFile(File cached, String name) async {
    final mimeType = lookupMimeType(name) ?? 'audio/mpeg';

    final savedPath = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        sourceFilePath: cached.path,
        fileName: name,
        mimeTypesFilter: [mimeType],
      ),
    );

    if (savedPath == null) {
      // Cache copy is no longer needed once the user cancelled saving.
      try {
        if (await cached.exists()) await cached.delete();
      } catch (_) {}
      return const FileTransferResult(status: FileSaveStatus.canceled);
    }

    return FileTransferResult(
      status: FileSaveStatus.saved,
      path: savedPath,
    );
  }

  /// Copies the audio to a temporary file and opens the share sheet.
  Future<FileShareResult> shareFile({
    required String url,
    String? fileName,
    void Function(int progress, int? total)? onProgress,
  }) async {
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      final name = fileName ?? deriveFileName(url);
      // Unique name so concurrent shares don't collide.
      tempFile = File(
        '${tempDir.path}/share_${DateTime.now().microsecondsSinceEpoch}_$name',
      );

      await _downloadToFile(url, tempFile, onProgress);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              tempFile.path,
              mimeType: lookupMimeType(name) ?? 'audio/mpeg',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          downloadFallbackEnabled: true,
        ),
      );

      return FileShareResult(
        shared: result.status != ShareResultStatus.unavailable,
      );
    } catch (e) {
      return FileShareResult(shared: false, error: e.toString());
    } finally {
      // Remove the temporary share copy.
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _downloadToFile(
    String url,
    File file,
    void Function(int, int?)? onProgress,
  ) async {
    final response = await _client.send(
      http.Request('GET', Uri.parse(url)),
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'HTTP ${response.statusCode} while downloading $url',
      );
    }

    final total = response.contentLength;
    final sink = file.openWrite();
    var downloaded = 0;

    try {
      await for (final chunk in response.stream) {
        downloaded += chunk.length;
        sink.add(chunk);
        onProgress?.call(downloaded, total);
      }
    } finally {
      await sink.close();
    }
  }
}