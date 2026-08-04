import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/supabase_service.dart';
import 'package:tatislam_app/features/sections/data/datasources/section_local_data_source.dart';
import 'package:tatislam_app/features/sections/data/datasources/section_remote_data_source.dart';
import 'package:tatislam_app/features/sections/data/repositories/section_repository_impl.dart';
import 'package:tatislam_app/features/sections/domain/repositories/section_repository.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

final sectionRemoteDataSourceProvider = Provider<SectionRemoteDataSource>((
  ref,
) {
  return SectionRemoteDataSource(SupabaseService.client);
});

final sectionLocalDataSourceProvider = Provider<SectionLocalDataSource>((ref) {
  return SectionLocalDataSource();
});

final sectionRepositoryProvider = Provider<SectionRepository>((ref) {
  return SectionRepositoryImpl(
    ref.watch(sectionRemoteDataSourceProvider),
    ref.watch(sectionLocalDataSourceProvider),
  );
});

/// Notifier that holds the current list of sections.
///
/// On first build it loads from the local cache immediately (fast path),
/// then triggers a background sync from Supabase. When the sync completes
/// the state is updated and the UI rebuilds automatically.
class SectionsNotifier extends Notifier<List<Section>> {
  @override
  List<Section> build() {
    // 1. Load from cache immediately (synchronous).
    final repo = ref.read(sectionRepositoryProvider);
    repo.getCachedSections().then((cached) {
      if (cached.isNotEmpty && state.isEmpty) {
        state = cached;
      }
    });

    // 2. Trigger background sync.
    _syncFromNetwork();
    return [];
  }

  Future<void> _syncFromNetwork() async {
    try {
      final repo = ref.read(sectionRepositoryProvider);
      final fresh = await repo.refreshSections();
      state = fresh;
    } catch (e) {
      // Keep showing cached data — network error is non-fatal.
    }
  }

  /// Force a full refresh from the network (used by pull-to-refresh).
  Future<void> refresh() async {
    try {
      final repo = ref.read(sectionRepositoryProvider);
      final fresh = await repo.refreshSections();
      state = fresh;
    } catch (e) {
      rethrow;
    }
  }
}

/// Provider for the current list of sections.
///
/// - Returns cached data immediately (no loading spinner for cached data).
/// - Silently syncs from Supabase in the background.
/// - On first-ever launch without internet, returns an empty list.
final sectionsProvider = NotifierProvider<SectionsNotifier, List<Section>>(
  SectionsNotifier.new,
);
