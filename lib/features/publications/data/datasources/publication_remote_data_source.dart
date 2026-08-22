import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import 'package:tatislam_app/core/constants/supabase_constants.dart';
import 'package:tatislam_app/core/error/exceptions.dart';
import 'package:tatislam_app/features/publications/data/models/content_block_model.dart';
import 'package:tatislam_app/features/publications/data/models/publication_model.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Raw aggregate for a single publication, as needed to build
/// `PublicationDetail`: the row itself, its ordered blocks and the ids of
/// the sections it belongs to.
class PublicationDetailRow {
  final PublicationModel publication;
  final List<ContentBlock> blocks;
  final List<String> sectionIds;

  const PublicationDetailRow({
    required this.publication,
    required this.blocks,
    required this.sectionIds,
  });
}

/// Talks to `publications`, `content_blocks` and `publication_sections`.
class PublicationRemoteDataSource {
  final SupabaseClient _client;

  PublicationRemoteDataSource(this._client);

  Future<List<PublicationModel>> getPublications({
    String? sectionId,
    String? searchQuery,
    String? type,
    int limit = 20,
    int offset = 0,
    bool includeAllStatuses =
        false, // New parameter to include all statuses for admin
  }) async {
    try {
      // If filtering by section, use a dedicated view that joins
      // publications ↔ publication_sections, so ORDER BY + LIMIT/OFFSET are
      // applied inside Postgres — only the requested page is fetched even for
      // sections with thousands of publications.
      if (sectionId != null) {
        var query = _client
            .from(SupabaseTables.publicationsBySectionView)
            .select()
            .eq('section_id', sectionId);

        // Only filter by status if not including all statuses (for admin access).
        // The view already excludes drafts for public callers; for admin we
        // query the base table path instead (see below).
        if (!includeAllStatuses) {
          // Public: view already filters status=published.
        }

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final escaped = searchQuery.trim().replaceAll(',', ' ');
          query = query.or('title.ilike.%$escaped%');
        }

        if (type != null && type.isNotEmpty) {
          query = query.eq('type', type);
        }

        final response = await query
            .order('published_at', ascending: false)
            .range(offset, offset + limit - 1);

        return response.map((row) => PublicationModel.fromJson(row)).toList();
      } else {
        // No section filter, use regular query
        var query = _client.from(SupabaseTables.publications).select();

        // Only filter by status if not including all statuses (for admin access)
        if (!includeAllStatuses) {
          query = query.eq('status', 'published');
        }

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final escaped = searchQuery.trim().replaceAll(',', ' ');
          query = query.or('title.ilike.%$escaped%');
        }

        if (type != null && type.isNotEmpty) {
          query = query.eq('type', type);
        }

        final response = await query
            .order('published_at', ascending: false)
            .range(offset, offset + limit - 1);

        return response.map((row) => PublicationModel.fromJson(row)).toList();
      }
    } catch (e) {
      throw ServerException('Failed to load publications: $e');
    }
  }

  Future<List<PublicationModel>> getPublicationsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _client
          .from(SupabaseTables.publications)
          .select()
          .inFilter('id', ids)
          .order('published_at', ascending: false);
      return response.map((row) => PublicationModel.fromJson(row)).toList();
    } catch (e) {
      throw ServerException('Failed to load publications: $e');
    }
  }

  Future<PublicationDetailRow> getPublicationDetail(String id) async {
    try {
      final publicationRow = await _client
          .from(SupabaseTables.publications)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (publicationRow == null) {
        throw NotFoundException('Publication "$id" not found');
      }

      final blockRows = await _client
          .from(SupabaseTables.contentBlocks)
          .select()
          .eq('publication_id', id)
          .order('order_index', ascending: true);

      final sectionRows = await _client
          .from(SupabaseTables.publicationSections)
          .select('section_id')
          .eq('publication_id', id);

      return PublicationDetailRow(
        publication: PublicationModel.fromJson(publicationRow),
        blocks: blockRows
            .map((row) => ContentBlockModel.fromJson(row))
            .toList(),
        sectionIds: sectionRows
            .map((row) => row['section_id'] as String)
            .toList(),
      );
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to load publication: $e');
    }
  }

  Future<PublicationModel> createPublication(PublicationModel model) async {
    try {
      final row = await _client
          .from(SupabaseTables.publications)
          .insert(model.toInsertJson())
          .select()
          .single();
      return PublicationModel.fromJson(row);
    } catch (e) {
      throw ServerException('Failed to create publication: $e');
    }
  }

  Future<PublicationModel> updatePublication(
    String id,
    PublicationModel model,
  ) async {
    try {
      final row = await _client
          .from(SupabaseTables.publications)
          .update(model.toInsertJson())
          .eq('id', id)
          .select()
          .single();
      return PublicationModel.fromJson(row);
    } catch (e) {
      throw ServerException('Failed to update publication: $e');
    }
  }

  Future<void> deletePublication(String id) async {
    try {
      await _client.from(SupabaseTables.publications).delete().eq('id', id);
    } catch (e) {
      throw ServerException('Failed to delete publication: $e');
    }
  }

  /// Crash-safe replace of every content block for [publicationId].
  ///
  /// Writes the new/edited blocks first (upsert by id) and only then removes
  /// blocks that are no longer present. If the write fails, the previous
  /// blocks stay intact instead of being wiped out first. Nothing else
  /// references `content_blocks.id`, so upserting by id is safe.
  Future<void> replaceBlocks(
    String publicationId,
    List<ContentBlock> blocks,
  ) async {
    try {
      final newIds =
          blocks.map((block) => block.id).where((id) => id.isNotEmpty).toSet();

      if (blocks.isNotEmpty) {
        final rows = blocks
            .map((block) => ContentBlockModel.toInsertJson(block, publicationId))
            .toList();
        await _client
            .from(SupabaseTables.contentBlocks)
            .upsert(rows, onConflict: 'id');
      }

      if (newIds.isEmpty) {
        // Nothing kept — remove every block for this publication.
        if (blocks.isEmpty) {
          await _client
              .from(SupabaseTables.contentBlocks)
              .delete()
              .eq('publication_id', publicationId);
        }
      } else {
        await _client
            .from(SupabaseTables.contentBlocks)
            .delete()
            .eq('publication_id', publicationId)
            .not('id', 'in', newIds.toList());
      }
    } catch (e) {
      throw ServerException('Failed to save content blocks: $e');
    }
  }

  Future<void> setSections(
    String publicationId,
    List<String> sectionIds,
  ) async {
    try {
      await _client
          .from(SupabaseTables.publicationSections)
          .delete()
          .eq('publication_id', publicationId);

      if (sectionIds.isEmpty) return;

      final rows = sectionIds
          .map(
            (sectionId) => {
              'publication_id': publicationId,
              'section_id': sectionId,
            },
          )
          .toList();
      await _client.from(SupabaseTables.publicationSections).insert(rows);
    } catch (e) {
      throw ServerException('Failed to update publication sections: $e');
    }
  }
}
