import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tatislam_app/core/error/exceptions.dart' as app;
import 'package:tatislam_app/core/storage/media_storage_repository.dart';

/// [MediaStorageRepository] implementation backed by Yandex Object Storage
/// via the `upload-media` Supabase Edge Function.
///
/// The Edge Function returns an S3 object key (e.g. `images/uuid.jpg`).
/// This repository maps between the app-level path convention and the
/// folder-based S3 structure.
class YandexMediaStorageRepository implements MediaStorageRepository {
  final SupabaseClient _client;

  /// Base URL for public Yandex Object Storage access.
  static const String _yandexEndpoint = 'https://storage.yandexcloud.net';
  static const String _yandexBucket = 'tatislam-media';

  YandexMediaStorageRepository(this._client);

  /// Maps an app-level Storage path to an S3 folder name.
  String _pathToFolder(String path) {
    if (path.startsWith('covers/')) return 'images';
    if (path.contains('/images/')) return 'images';
    if (path.contains('/audio/')) return 'audio';
    if (path.contains('/video/')) return 'videos';
    return 'images';
  }

  @override
  Future<String> upload(String path, Uint8List bytes, {String? contentType}) async {
    try {
      final folder = _pathToFolder(path);
      final mimeType = contentType ?? 'application/octet-stream';

      // Get the user's current session token
      final session = _client.auth.currentSession;
      if (session == null) {
        throw app.StorageException('Authentication required');
      }
      final accessToken = session.accessToken;

      // Build the Edge Function URL directly using the Supabase project URL
      const projectUrl = String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://vboffcgpkdruvqgdfpbp.supabase.co',
      );
      final functionUrl = '$projectUrl/functions/v1/upload-media?folder=$folder';

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(functionUrl));
      request.headers['apikey'] = accessToken;
      request.headers['Authorization'] = 'Bearer $accessToken';
      final mediaParts = mimeType.split('/');
      final mediaType = MediaType(
        mediaParts.isNotEmpty ? mediaParts[0] : 'application',
        mediaParts.length > 1 ? mediaParts[1] : 'octet-stream',
      );
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: path.split('/').last,
        contentType: mediaType,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw app.StorageException(
          body['error'] as String? ?? 'Failed to upload file (${response.statusCode})',
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

    for (final key in paths) {
      try {
        final request = http.Request('POST', Uri.parse(deleteUrl));
        request.headers['apikey'] = accessToken;
        request.headers['Authorization'] = 'Bearer $accessToken';
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode({'key': key});

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          throw app.StorageException(
            body['error'] as String? ?? 'Failed to delete file (${response.statusCode})',
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
    return '$_yandexEndpoint/$_yandexBucket/$path';
  }
}