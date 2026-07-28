import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import 'package:tatislam_app/core/constants/supabase_constants.dart';
import 'package:tatislam_app/core/error/exceptions.dart';
import 'package:tatislam_app/core/utils/slugify.dart';
import 'package:tatislam_app/features/sections/data/models/section_model.dart';

/// Talks to the `sections` table in Supabase.
class SectionRemoteDataSource {
  final SupabaseClient _client;

  SectionRemoteDataSource(this._client);

  Future<List<SectionModel>> getSections({required bool includeHidden}) async {
    try {
      debugPrint('SectionRemoteDataSource: Starting to fetch sections from Supabase');
      debugPrint('SectionRemoteDataSource: includeHidden=$includeHidden');
      
      var query = _client.from(SupabaseTables.sections).select();
      if (!includeHidden) {
        query = query.eq('is_visible', true);
      }
      final response = await query.order('sort_order', ascending: true);
      
      debugPrint('SectionRemoteDataSource: Finished fetching sections from Supabase, count: ${response.length}');
      return response.map((row) => SectionModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint('SectionRemoteDataSource: Error fetching sections: $e');
      throw ServerException('Failed to load sections: $e');
    }
  }

  Future<SectionModel> createSection(String name) async {
    try {
      final nextSortOrder = await _nextSortOrder();
      final baseSlug = slugify(name);
      final row = await _insertWithUniqueSlug(name, baseSlug, nextSortOrder);
      return SectionModel.fromJson(row);
    } catch (e) {
      throw ServerException('Failed to create section: $e');
    }
  }

  Future<Map<String, dynamic>> _insertWithUniqueSlug(
    String name,
    String baseSlug,
    int sortOrder,
  ) async {
    var slug = baseSlug;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        return await _client
            .from(SupabaseTables.sections)
            .insert({
              'name': name,
              'slug': slug,
              'sort_order': sortOrder,
            })
            .select()
            .single();
      } on PostgrestException catch (e) {
        final isUniqueViolation = e.code == '23505';
        if (!isUniqueViolation || attempt == 4) rethrow;
        slug = '$baseSlug-${attempt + 2}';
      }
    }
    throw const ServerException('Could not generate a unique slug');
  }

  Future<int> _nextSortOrder() async {
    final response = await _client
        .from(SupabaseTables.sections)
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1);
    if (response.isEmpty) return 0;
    return (response.first['sort_order'] as int) + 1;
  }

  Future<SectionModel> renameSection(String id, String name) async {
    try {
      final row = await _client
          .from(SupabaseTables.sections)
          .update({'name': name})
          .eq('id', id)
          .select()
          .single();
      return SectionModel.fromJson(row);
    } catch (e) {
      throw ServerException('Failed to rename section: $e');
    }
  }

  Future<SectionModel> setVisibility(String id, bool isVisible) async {
    try {
      final row = await _client
          .from(SupabaseTables.sections)
          .update({'is_visible': isVisible})
          .eq('id', id)
          .select()
          .single();
      return SectionModel.fromJson(row);
    } catch (e) {
      throw ServerException('Failed to update section visibility: $e');
    }
  }

  Future<SectionModel> updateBackground(String id, String? backgroundImage) async {
    try {
      final row = await _client
          .from(SupabaseTables.sections)
          .update({'background_image': backgroundImage})
          .eq('id', id)
          .select()
          .single();
      return SectionModel.fromJson(row);
    } catch (e) {
      throw ServerException('Failed to update section background: $e');
    }
  }

  Future<void> deleteSection(String id) async {
    try {
      await _client.from(SupabaseTables.sections).delete().eq('id', id);
    } catch (e) {
      throw ServerException('Failed to delete section: $e');
    }
  }

  Future<void> reorderSections(List<String> orderedIds) async {
    try {
      for (var i = 0; i < orderedIds.length; i++) {
        await _client
            .from(SupabaseTables.sections)
            .update({'sort_order': i})
            .eq('id', orderedIds[i]);
      }
    } catch (e) {
      throw ServerException('Failed to reorder sections: $e');
    }
  }
  
  /// Moves a section up one position by swapping sort_order with the section above it.
  /// Returns the updated section, or null if the section is already at the top.
  Future<SectionModel?> moveSectionUp(String id, int currentSortOrder) async {
    try {
      // Find the section with the next lower sort_order
      final response = await _client
          .from(SupabaseTables.sections)
          .select()
          .lt('sort_order', currentSortOrder)
          .order('sort_order', ascending: false)
          .limit(1);
      
      if (response.isEmpty) {
        // Already at the top, can't move up
        return null;
      }
      
      final aboveSection = SectionModel.fromJson(response.first);
      
      // Swap sort orders
      await _client
          .from(SupabaseTables.sections)
          .update({'sort_order': aboveSection.sortOrder})
          .eq('id', id);
      
      await _client
          .from(SupabaseTables.sections)
          .update({'sort_order': currentSortOrder})
          .eq('id', aboveSection.id);
      
      // Return null since the UI will refresh the list anyway
      return null;
    } catch (e) {
      throw ServerException('Failed to move section up: $e');
    }
  }
  
  /// Moves a section down one position by swapping sort_order with the section below it.
  /// Returns the updated section, or null if the section is already at the bottom.
  Future<SectionModel?> moveSectionDown(String id, int currentSortOrder) async {
    try {
      // Find the section with the next higher sort_order
      final response = await _client
          .from(SupabaseTables.sections)
          .select()
          .gt('sort_order', currentSortOrder)
          .order('sort_order', ascending: true)
          .limit(1);
      
      if (response.isEmpty) {
        // Already at the bottom, can't move down
        return null;
      }
      
      final belowSection = SectionModel.fromJson(response.first);
      
      // Swap sort orders
      await _client
          .from(SupabaseTables.sections)
          .update({'sort_order': belowSection.sortOrder})
          .eq('id', id);
      
      await _client
          .from(SupabaseTables.sections)
          .update({'sort_order': currentSortOrder})
          .eq('id', belowSection.id);
      
      // Return null since the UI will refresh the list anyway
      return null;
    } catch (e) {
      throw ServerException('Failed to move section down: $e');
    }
  }
}
