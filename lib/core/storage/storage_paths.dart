import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Builds the canonical Storage object paths used by the `media` bucket.
///
/// See SUPABASE_SETUP.md §5 for the folder convention this mirrors:
///
///   media/
///     covers/`<publicationId>`.`<ext>`
///     blocks/`<publicationId>`/images/`<blockId>`.`<ext>`
///     blocks/`<publicationId>`/audio/`<blockId>`.`<ext>`
///
/// The DB only ever stores the path returned here — never a public URL.
class StoragePaths {
  StoragePaths._();

  static String cover(String publicationId, String extension) =>
      'covers/$publicationId.${_clean(extension)}';

  static String blockImage(
    String publicationId,
    String extension, {
    String? blockId,
  }) =>
      'blocks/$publicationId/images/${blockId ?? _uuid.v4()}.${_clean(extension)}';

  static String blockAudio(
    String publicationId,
    String extension, {
    String? blockId,
  }) =>
      'blocks/$publicationId/audio/${blockId ?? _uuid.v4()}.${_clean(extension)}';

  /// Path for a video file uploaded to the `videos` folder.
  static String blockVideo(
    String publicationId,
    String extension, {
    String? blockId,
  }) =>
      'blocks/$publicationId/videos/${blockId ?? _uuid.v4()}.${_clean(extension)}';

  /// Path for an arbitrary file (pdf, docx, ...) uploaded to the `files` folder.
  static String blockFile(
    String publicationId,
    String extension, {
    String? blockId,
  }) =>
      'blocks/$publicationId/files/${blockId ?? _uuid.v4()}.${_clean(extension)}';

  /// Path for the full-bleed photo backing a `photo` type publication.
  static String photo(
    String publicationId,
    String extension, {
    String? photoId,
  }) =>
      'photos/$publicationId/${photoId ?? _uuid.v4()}.${_clean(extension)}';

  static String _clean(String extension) {
    var cleaned = extension.replaceFirst('.', '').trim().toLowerCase();
    // Never produce a path ending in a bare dot (e.g. `<id>.`), which some
    // storage layers reject. A safe placeholder keeps the path well-formed.
    return cleaned.isEmpty ? 'bin' : cleaned;
  }
}
