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

  /// Path for the full-bleed photo backing a `photo` type publication.
  static String photo(
    String publicationId,
    String extension, {
    String? photoId,
  }) =>
      'photos/$publicationId/${photoId ?? _uuid.v4()}.${_clean(extension)}';

  static String _clean(String extension) =>
      extension.replaceFirst('.', '').toLowerCase();
}
