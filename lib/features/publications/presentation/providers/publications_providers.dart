import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/sections/presentation/providers/selected_section_provider.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';

import 'publication_state_providers.dart';
export 'publication_state_providers.dart';

/// Toggle favorites filter on/off (uses the legacy state below).
final toggleFavoritesFilterProvider = Provider<void Function()>((ref) {
  return () {
    final current = ref.read(favoritesFilterProvider);
    ref.read(favoritesFilterProvider.notifier).state = !current;
  };
});

/// Page size loaded at once by the main grid.
const int kMainPageSize = 20;

/// Holds a loaded page and whether more pages exist.
class PublicationsPage {
  final List<Publication> items;
  final bool hasMore;

  const PublicationsPage({required this.items, required this.hasMore});
}

/// Stateful notifier that loads publication pages incrementally. Resets
/// whenever filters or the version counter change. Keeps the last successful
/// page cached so a refresh shows stale-but-usable content instead of a
/// blank loader, and appends new pages via [loadMore].
class MainPublicationsNotifier
    extends Notifier<AsyncValue<PublicationsPage>> {
  PublicationsPage? _cached;
  String? _lastSectionId;
  String? _lastQuery;
  bool _concurrentLoadInFlight = false;

  @override
  AsyncValue<PublicationsPage> build() {
    // Watch mutable inputs so we auto-refresh when they change.
    ref.watch(publicationListVersionProvider);
    final search = ref.watch(searchQueryProvider);
    final selected = ref.watch(selectedSectionProvider);
    final favoritesOnly = ref.watch(favoritesFilterProvider);

    final sectionId = selected?.id;
    final query = search.isEmpty ? null : search;

    // If the section/search changed, the cached page belongs to the old
    // filters — discard it instead of showing stale content.
    if (sectionId != _lastSectionId || query != _lastQuery) {
      _cached = null;
    }
    _lastSectionId = sectionId;
    _lastQuery = query;

    // Provide the cached page immediately (keeps the grid visible during a
    // background refresh after invalidate), then reload in the background.
    final cached = _cached;
    _cached = null;
    _loadFirstPage(sectionId, query, favoritesOnly);
    if (cached != null) {
      return AsyncData(cached);
    }
    return const AsyncLoading();
  }

  Future<void> _loadFirstPage(
    String? sectionId,
    String? query,
    bool favoritesOnly,
  ) async {
    try {
      final pubs = await ref.read(getPublicationsWithFiltersProvider)(
        sectionId: sectionId,
        searchQuery: query,
        limit: kMainPageSize,
        offset: 0,
      );

      var pageItems = pubs;
      if (favoritesOnly) {
        final favoriteIds = await ref
            .read(favoritesProvider.future)
            .then((list) => list.map((p) => p.id).toSet());
        pageItems = pubs.where((p) => favoriteIds.contains(p.id)).toList();
      }

      _cached = PublicationsPage(
        items: pageItems,
        hasMore: pubs.length >= kMainPageSize,
      );
      if (ref.mounted) {
        state = AsyncData(_cached!);
      }
    } catch (error, stack) {
      if (ref.mounted) {
        state = AsyncError(error, stack);
      }
    }
  }

  /// Pull-to-refresh: keeps showing current content while a fresh first page
  /// loads, then swaps it in.
  Future<void> refresh() async {
    final search = ref.read(searchQueryProvider);
    final selected = ref.read(selectedSectionProvider);
    final favoritesOnly = ref.read(favoritesFilterProvider);
    await _loadFirstPage(
      selected?.id,
      search.isEmpty ? null : search,
      favoritesOnly,
    );
  }

  /// Appends the next page of publications. A concurrent call while a load is
  /// in flight is ignored.
  Future<void> loadMore() async {
    if (_concurrentLoadInFlight) return;
    final current = state;
    if (current is! AsyncData<PublicationsPage>) return;
    final page = current.value;
    if (!page.hasMore) return;

    final search = ref.read(searchQueryProvider);
    final selected = ref.read(selectedSectionProvider);

    _concurrentLoadInFlight = true;
    try {
      final next = await ref.read(getPublicationsWithFiltersProvider)(
        sectionId: selected?.id,
        searchQuery: search.isEmpty ? null : search,
        limit: kMainPageSize,
        offset: page.items.length,
      );
      final merged = [...page.items, ...next];
      _cached = PublicationsPage(
        items: merged,
        hasMore: next.length >= kMainPageSize,
      );
      if (ref.mounted) {
        state = AsyncData(_cached!);
      }
    } catch (error, stack) {
      if (ref.mounted) {
        state = AsyncError(error, stack);
      }
    } finally {
      _concurrentLoadInFlight = false;
    }
  }
}

/// Main publications provider — paginated.
final mainPublicationsProvider =
    NotifierProvider<MainPublicationsNotifier, AsyncValue<PublicationsPage>>(
      MainPublicationsNotifier.new,
    );

/// Filtered publications — kept for API compatibility, simply returns
/// [mainPublicationsProvider] items.
final filteredPublicationsProvider = Provider<AsyncValue<List<Publication>>>(
  (ref) {
    final async = ref.watch(mainPublicationsProvider);
    return async.when(
      data: (page) => AsyncData(page.items),
      loading: () => const AsyncLoading(),
      error: (e, s) => AsyncError(e, s),
    );
  },
);