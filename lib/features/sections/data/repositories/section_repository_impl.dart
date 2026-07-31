import 'package:tatislam_app/features/sections/data/datasources/section_local_data_source.dart';
import 'package:tatislam_app/features/sections/data/datasources/section_remote_data_source.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';
import 'package:tatislam_app/features/sections/domain/repositories/section_repository.dart';

/// Repository that implements a cache-first strategy for sections.
///
/// - `getSections()` returns cached data immediately, then fetches fresh data
///   from Supabase in the background and updates the cache.
/// - `getCachedSections()` returns only what's in the local cache (no network).
/// - All write operations (create, rename, delete, reorder) go directly to
///   Supabase and invalidate the local cache afterwards.
class SectionRepositoryImpl implements SectionRepository {
  final SectionRemoteDataSource _remote;
  final SectionLocalDataSource _local;

  SectionRepositoryImpl(this._remote, this._local);

  @override
  Future<List<Section>> getSections({bool includeHidden = false}) async {
    // Admin callers (includeHidden: true) always need fresh data —
    // the local cache is built from public (visible-only) fetches and
    // would hide hidden sections from the admin UI.
    if (includeHidden) {
      return refreshSections(includeHidden: true);
    }

    // Public callers: return cached data immediately (fast path).
    final cached = _local.getCachedSections();
    if (cached.isNotEmpty) {
      final result = cached.where((s) => s.isVisible).toList();
      if (result.isNotEmpty) {
        return result.map((m) => m.toEntity()).toList();
      }
    }

    // No cache — fetch from network.
    final models = await _remote.getSections(includeHidden: false);
    _local.cacheSections(models);
    return models.map((m) => m.toEntity()).toList();
  }

  /// Returns sections from the local cache only, without any network call.
  /// Returns an empty list if nothing is cached.
  @override
  Future<List<Section>> getCachedSections({bool includeHidden = false}) async {
    final cached = _local.getCachedSections();
    if (cached.isEmpty) return [];
    final result = includeHidden
        ? cached
        : cached.where((s) => s.isVisible).toList();
    return result.map((m) => m.toEntity()).toList();
  }

  /// Fetches fresh sections from Supabase and updates the local cache.
  /// Returns the fresh list.
  @override
  Future<List<Section>> refreshSections({bool includeHidden = false}) async {
    final models = await _remote.getSections(includeHidden: includeHidden);
    _local.cacheSections(models);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Section> createSection(String name) async {
    final model = await _remote.createSection(name);
    return model.toEntity();
  }

  @override
  Future<Section> renameSection(String id, String name) async {
    final model = await _remote.renameSection(id, name);
    return model.toEntity();
  }

  @override
  Future<Section> setVisibility(String id, bool isVisible) async {
    final model = await _remote.setVisibility(id, isVisible);
    return model.toEntity();
  }

  @override
  Future<void> deleteSection(String id) => _remote.deleteSection(id);

  @override
  Future<void> reorderSections(List<String> orderedIds) =>
      _remote.reorderSections(orderedIds);
  
  @override
  Future<Section?> moveSectionUp(Section section) async {
    final model = await _remote.moveSectionUp(section.id, section.sortOrder);
    return model?.toEntity();
  }
  
  @override
  Future<Section?> moveSectionDown(Section section) async {
    final model = await _remote.moveSectionDown(section.id, section.sortOrder);
    return model?.toEntity();
  }

  @override
  Future<Section> setBackgroundImage(String id, String? backgroundImage) async {
    final model = await _remote.updateBackground(id, backgroundImage);
    return model.toEntity();
  }
}
