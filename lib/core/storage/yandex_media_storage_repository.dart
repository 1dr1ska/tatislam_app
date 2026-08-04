import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart' as mime;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tatislam_app/core/error/exceptions.dart' as app;
import 'package:tatislam_app/core/storage/media_storage_repository.dart';

/// [MediaStorageRepository] implementation backed by Yandex Object Storage
/// via the `upload-media` Supabase Edge Function.
///
/// The Edge Function returns an S3 object key (e.g. `images/uuid.jpg`).
/// This key is the single source of truth — it is stored in PostgreSQL and
/// used by [publicUrlFor] to build the public URL.
class YandexMediaStorageRepository implements MediaStorageRepository {
  final SupabaseClient _client;

  static const String _yandexEndpoint = 'https://storage.yandexcloud.net';
  static const String _yandexBucket = 'tatislam-media';

  YandexMediaStorageRepository(this._client);

  /// Maps an app-level Storage path to an S3 folder name.
  ///
  /// The folder determines where the file is stored in Yandex Object Storage.
  /// Must match the folders allowed by the Edge Function.
  String _pathToFolder(String path) {
    if (path.startsWith('covers/')) return 'covers';
    if (path.contains('/images/')) return 'images';
    if (path.contains('/audio/')) return 'audio';
    if (path.contains('/video/')) return 'videos';
    return 'images';
  }

  /// Infers MIME type from the file extension using `package:mime`.
  ///
  /// Falls back to `application/octet-stream` if unknown (shouldn't happen
  /// for real files, but prevents crashes).
  String _mimeFromExtension(String path) {
    final ext = path.split('.').last;
    final mimeType = mime.lookupMimeType('file.$ext');
    return mimeType ?? 'application/octet-stream';
  }

  @override
  Future<String> upload(
    String path,
    Uint8List bytes, {
    String? contentType,
  }) async {
    try {
      final folder = _pathToFolder(path);
      final mimeType = contentType ?? _mimeFromExtension(path);
      final filename = path.split('/').last;

      final session = _client.auth.currentSession;
      if (session == null) {
        throw app.StorageException('Authentication required');
      }
      final accessToken = session.accessToken;

      const projectUrl = String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://vboffcgpkdruvqgdfpbp.supabase.co',
      );
      final functionUrl =
          '$projectUrl/functions/v1/upload-media?folder=$folder';

      final request = http.MultipartRequest('POST', Uri.parse(functionUrl));
      request.headers['apikey'] = accessToken;
      request.headers['Authorization'] = 'Bearer $accessToken';
      final mediaParts = mimeType.split('/');
      final mediaType = MediaType(
        mediaParts.isNotEmpty ? mediaParts[0] : 'application',
        mediaParts.length > 1 ? mediaParts[1] : 'octet-stream',
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw app.StorageException(
          body['error'] as String? ??
              'Failed to upload file (${response.statusCode})',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final key = data['key'] as String;
      return key;
    } catch (e) {
      if (e is app.StorageException) rethrow;
      throw app.StorageException('Failed to upload "$path": $e');
    }
  }

  @override
  Future<void> delete(List<String> paths) async {
    if (paths.isEmpty) return;

    // Filter out empty paths — they would be rejected by the Edge Function
    // and cause a confusing error. An empty path means no file was uploaded
    // for that field (e.g. no cover image was set).
    final nonEmptyPaths = paths.where((p) => p.isNotEmpty).toList();

    if (nonEmptyPaths.isEmpty) {
      return;
    }

    final session = _client.auth.currentSession;
    if (session == null) {
      throw app.StorageException('Authentication required');
    }
    final accessToken = session.accessToken;

    const projectUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://vboffcgpkdruvqgdfpbp.supabase.co',
    );
    final deleteUrl = '$projectUrl/functions/v1/delete-media';

    for (final key in nonEmptyPaths) {
      try {
        final body = {'key': key};

        final request = http.Request('POST', Uri.parse(deleteUrl));
        request.headers['apikey'] = accessToken;
        request.headers['Authorization'] = 'Bearer $accessToken';
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          throw app.StorageException(
            body['error'] as String? ??
                'Failed to delete file (${response.statusCode})',
          );
        }
      } catch (e) {
        if (e is app.StorageException) rethrow;
        throw app.StorageException('Failed to delete "$key": $e');
      }
    }
  }

  @override
  String publicUrlFor(String path) {
    // path is the S3 key returned by upload() and stored in PostgreSQL
    return '$_yandexEndpoint/$_yandexBucket/$path';
  }
}
