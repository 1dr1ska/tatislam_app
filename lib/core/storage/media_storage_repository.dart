import 'dart:typed_data';

/// Abstraction over the `media` Storage bucket.
///
/// The DB never stores public URLs (see SUPABASE_SETUP.md §1) — only paths.
/// This repository is the single place that uploads bytes to a path and
/// resolves a path to a public URL, so bucket/CDN changes never ripple into
/// feature code.
abstract class MediaStorageRepository {
  /// Uploads [bytes] to [path] in the media bucket, overwriting if present.
  /// Returns the same [path] for convenience.
  Future<String> upload(String path, Uint8List bytes, {String? contentType});

  /// Deletes one or more objects by path. Missing objects are ignored.
  Future<void> delete(List<String> paths);

  /// Resolves a Storage path to a publicly accessible URL.
  String publicUrlFor(String path);
}
