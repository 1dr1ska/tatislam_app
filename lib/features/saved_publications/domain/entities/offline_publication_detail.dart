import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

/// The fully offline-readable body of a saved publication.
///
/// [blocks] keep their original storage paths (so the UI stays identical to
/// the online rendering); [mediaFiles] maps each downloaded storage path to a
/// local `file://` URI that widgets should use instead.
class OfflinePublicationDetail {
  final Publication publication;
  final List<ContentBlock> blocks;
  final List<String> sectionIds;

  /// storagePath -> local `file://` URI (images, audio, files).
  final Map<String, String> mediaFiles;

  /// True when the publication contains online-only (video) content.
  final bool hasOnlineVideo;

  const OfflinePublicationDetail({
    required this.publication,
    required this.blocks,
    required this.sectionIds,
    required this.mediaFiles,
    required this.hasOnlineVideo,
  });
}