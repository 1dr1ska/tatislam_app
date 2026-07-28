import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';

/// Boundary for all publication read/write operations.
///
/// Reads are split into two granularities on purpose:
///  - [getPublications] returns lightweight metadata for lists (home,
///    catalog, search, favorites) without ever loading content blocks.
///  - [getPublicationDetail] returns the full aggregate (blocks + section
///    ids) for the single publication being viewed or edited.
abstract class PublicationRepository {
  /// [sectionId] filters to publications belonging to that section.
  /// [searchQuery] matches against title/description (see SUPABASE_SETUP.md
  /// §4 for the search strategy).
  /// [type] filters by publication type ('audio', 'video', 'article', etc.).
  /// [includeAllStatuses] when true, includes all publications regardless of status (for admin access).
  Future<List<Publication>> getPublications({
    String? sectionId,
    String? searchQuery,
    String? type,
    int limit = 20,
    int offset = 0,
    bool includeAllStatuses = false,
  });

  /// Used to resolve favorites (stored locally as ids only) into full
  /// [Publication] metadata.
  Future<List<Publication>> getPublicationsByIds(List<String> ids);

  Future<PublicationDetail> getPublicationDetail(String id);

  // ---------------------------------------------------------------------
  // Admin-only write operations (enforced server-side via RLS regardless).
  // ---------------------------------------------------------------------

  Future<Publication> createPublication({
    required String title,
    required String description,
    String? icon,
    required DateTime publishedAt,
    required String type,
    String? status,
  });

  Future<Publication> updatePublication({
    required String id,
    required String title,
    required String description,
    String? icon,
    required DateTime publishedAt,
    required String type,
    String? status,
  });

  /// Deletes the publication and, via DB cascade, its blocks and section
  /// memberships. Associated Storage objects are cleaned up best-effort.
  Future<void> deletePublication(String id);

  /// Replaces the publication's entire ordered block list. Content editing
  /// is infrequent and blocks are few, so a full replace on save is simpler
  /// and more robust than diffing individual block changes.
  Future<void> replaceBlocks(String publicationId, List<ContentBlock> blocks);

  /// Replaces the publication's entire set of section memberships.
  Future<void> setSections(String publicationId, List<String> sectionIds);
}