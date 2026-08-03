import 'package:flutter/foundation.dart';
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
    bool includeAllStatuses = false, // New parameter to include all statuses for admin
  }) async {
    try {
      debugPrint('PublicationRemoteDataSource: Starting to fetch publications from Supabase');
      debugPrint('PublicationRemoteDataSource: sectionId=$sectionId, searchQuery=$searchQuery, type=$type, limit=$limit, offset=$offset, includeAllStatuses=$includeAllStatuses');
      
      // Check for special admin access keyword
      if (searchQuery != null && searchQuery.trim().toLowerCase() == 'admin') {
        // Return special admin publication
        final adminPublication = PublicationModel(
          id: 'admin_access',
          title: 'Доступ к админке',
          publishedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          type: 'admin',
          status: 'published',
          primarySectionId: '',
        );
        return [adminPublication];
      }
      
      // If filtering by section, first get publication IDs for that section
      if (sectionId != null) {
        final sectionPublications = await _client
            .from(SupabaseTables.publicationSections)
            .select('publication_id')
            .eq('section_id', sectionId);
        
        final publicationIds = sectionPublications
            .map((row) => row['publication_id'] as String)
            .toList();
        
        if (publicationIds.isEmpty) {
          return [];
        }
        
        var query = _client
            .from(SupabaseTables.publications)
            .select()
            .inFilter('id', publicationIds);
        
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
            
        debugPrint('PublicationRemoteDataSource: Finished fetching publications from Supabase, count: ${response.length}');
        
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
            
        debugPrint('PublicationRemoteDataSource: Finished fetching publications from Supabase, count: ${response.length}');
        
        return response.map((row) => PublicationModel.fromJson(row)).toList();
      }
    } catch (e) {
      debugPrint('PublicationRemoteDataSource: Error fetching publications: $e');
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
    debugPrint('PublicationRemoteDataSource.getPublicationDetail: called with id="$id"');
    try {
      debugPrint('PublicationRemoteDataSource.getPublicationDetail: querying publications table with eq("id", "$id")');
      final publicationRow =
          await _client.from(SupabaseTables.publications).select().eq('id', id).maybeSingle();
      debugPrint('PublicationRemoteDataSource.getPublicationDetail: publicationRow=$publicationRow');
      if (publicationRow == null) {
        debugPrint('PublicationRemoteDataSource.getPublicationDetail: NOT FOUND for id="$id"');
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
        blocks: blockRows.map((row) => ContentBlockModel.fromJson(row)).toList(),
        sectionIds: sectionRows.map((row) => row['section_id'] as String).toList(),
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

  Future<PublicationModel> updatePublication(String id, PublicationModel model) async {
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

  /// Full replace: delete every existing block for [publicationId], then
  /// insert [blocks] as given. Nothing else references `content_blocks.id`,
  /// so this is safe and far simpler than diffing individual block edits.
  Future<void> replaceBlocks(String publicationId, List<ContentBlock> blocks) async {
    try {
      await _client
          .from(SupabaseTables.contentBlocks)
          .delete()
          .eq('publication_id', publicationId);

      if (blocks.isEmpty) return;

      final rows = blocks
          .map((block) => ContentBlockModel.toInsertJson(block, publicationId))
          .toList();
      await _client.from(SupabaseTables.contentBlocks).insert(rows);
    } catch (e) {
      throw ServerException('Failed to save content blocks: $e');
    }
  }

  Future<void> setSections(String publicationId, List<String> sectionIds) async {
    try {
      await _client
          .from(SupabaseTables.publicationSections)
          .delete()
          .eq('publication_id', publicationId);

      if (sectionIds.isEmpty) return;

      final rows = sectionIds
          .map((sectionId) => {'publication_id': publicationId, 'section_id': sectionId})
          .toList();
      await _client.from(SupabaseTables.publicationSections).insert(rows);
    } catch (e) {
      throw ServerException('Failed to update publication sections: $e');
    }
  }
}
