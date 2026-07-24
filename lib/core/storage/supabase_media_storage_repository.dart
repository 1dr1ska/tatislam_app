import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show StorageException;
import 'package:tatislam_app/core/constants/supabase_constants.dart';
import 'package:tatislam_app/core/error/exceptions.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';

/// [MediaStorageRepository] implementation backed by Supabase Storage.
class SupabaseMediaStorageRepository implements MediaStorageRepository {
  final SupabaseClient _client;

  SupabaseMediaStorageRepository(this._client);

  StorageFileApi get _bucket => _client.storage.from(SupabaseBuckets.media);

  @override
  Future<String> upload(String path, Uint8List bytes, {String? contentType}) async {
    try {
      await _bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      return path;
    } on supabase.StorageException catch (e) {
      throw StorageException('Failed to upload "$path": ${e.message}');
    }
  }

  @override
  Future<void> delete(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _bucket.remove(paths);
    } on supabase.StorageException {
      // Best-effort cleanup: a missing object should never block the
      // caller's own delete/update flow.
    }
  }

  @override
  String publicUrlFor(String path) => _bucket.getPublicUrl(path);
}
