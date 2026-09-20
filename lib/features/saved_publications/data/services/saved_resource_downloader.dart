import 'dart:io';

import 'package:dio/dio.dart';

/// Downloads one resource URL into [destination].
///
/// Returns the final byte size on disk, or null when unknown. [onProgress]
/// reports the number of bytes received so far for this single resource.
typedef DownloadFile = Future<int?> Function(
  String url,
  String destination, {
  void Function(int received)? onProgress,
});

/// Performs a `HEAD` request and returns the `Content-Length`, or null when
/// unavailable.
typedef HeadFile = Future<int?> Function(String url);

/// Raised when a save operation is cancelled mid-flight.
class SavedDownloadCancelled implements Exception {
  final String publicationId;

  const SavedDownloadCancelled(this.publicationId);
}

/// Real [DownloadFile]/[HeadFile] backed by Dio.
DownloadFile dioDownloadFile(Dio dio) {
  return (url, destination, {onProgress}) async {
    await dio.download(
      url,
      destination,
      onReceiveProgress: (received, _) => onProgress?.call(received),
    );
    final f = File(destination);
    return f.existsSync() ? f.lengthSync() : null;
  };
}

/// Real [HeadFile] backed by Dio.
HeadFile dioHeadFile(Dio dio) {
  return (url) async {
    final response = await dio.head<void>(url);
    final raw = response.headers.value('content-length');
    return raw == null ? null : int.tryParse(raw);
  };
}