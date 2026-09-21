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
  final bool isLoadingMore;
  final Object? loadMoreError;

  const PublicationsPage({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });
}

/// The inputs that define one feed. Keeping a snapshot with each request
/// prevents a slow response for an old search/section/filter from replacing a
/// newer feed.
class _PublicationsFilter {
  final String? sectionId;
  final String? query;
  final bool favoritesOnly;

  const _PublicationsFilter({
    required this.sectionId,
    required this.query,
    required this.favoritesOnly,
  });

  @override
  bool operator ==(Object other) =>
      other is _PublicationsFilter &&
      other.sectionId == sectionId &&
      other.query == query &&
      other.favoritesOnly == favoritesOnly;

  @override
  int get hashCode => Object.hash(sectionId, query, favoritesOnly);
}

/// Stateful notifier that loads publication pages incrementally. Resets
/// whenever filters or the version counter change. Keeps the last successful
/// page cached so a refresh shows stale-but-usable content instead of a
/// blank loader, and appends new pages via [loadMore].
class MainPublicationsNotifier extends Notifier<AsyncValue<PublicationsPage>> {
  PublicationsPage? _cached;
  _PublicationsFilter? _lastFilter;
  int _requestGeneration = 0;
  bool _loadMoreInFlight = false;

  @override
  AsyncValue<PublicationsPage> build() {
    // Watch mutable inputs so we auto-refresh when they change.
    ref.watch(publicationListVersionProvider);
    final search = ref.watch(searchQueryProvider);
    final selected = ref.watch(selectedSectionProvider);
    final favoritesOnly = ref.watch(favoritesFilterProvider);

    final filter = _PublicationsFilter(
      sectionId: selected?.id,
      query: search.isEmpty ? null : search,
      favoritesOnly: favoritesOnly,
    );

    // A favorite change must also rebuild this provider when the favorites
    // view is active. The actual list is read by [_loadFirstPage].
    if (favoritesOnly) {
      ref.watch(favoritesProvider);
    }

    // If the section/search changed, the cached page belongs to the old
    // filters — discard it instead of showing stale content.
    if (filter != _lastFilter) {
      _cached = null;
    }
    _lastFilter = filter;

    // Provide the cached page immediately (keeps the grid visible during a
    // background refresh after invalidate), then reload in the background.
    final cached = _cached;
    _cached = null;
    _loadFirstPage(filter);
    if (cached != null) {
      return AsyncData(cached);
    }
    return const AsyncLoading();
  }

  Future<void> _loadFirstPage(_PublicationsFilter filter) async {
    final requestGeneration = ++_requestGeneration;
    // A first-page request supersedes any pending pagination request.
    _loadMoreInFlight = false;
    try {
      final page = filter.favoritesOnly
          ? await _loadFavoritesPage(filter)
          : await _loadRemoteFirstPage(filter);

      if (ref.mounted && requestGeneration == _requestGeneration) {
        _cached = page;
        state = AsyncData(_cached!);
      }
    } catch (error, stack) {
      if (ref.mounted && requestGeneration == _requestGeneration) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<PublicationsPage> _loadRemoteFirstPage(
    _PublicationsFilter filter,
  ) async {
    final publications = await ref.read(getPublicationsWithFiltersProvider)(
      sectionId: filter.sectionId,
      searchQuery: filter.query,
      limit: kMainPageSize,
      offset: 0,
    );
    return PublicationsPage(
      items: publications,
      hasMore: publications.length >= kMainPageSize,
    );
  }

  Future<PublicationsPage> _loadFavoritesPage(
    _PublicationsFilter filter,
  ) async {
    // Favorites are already a finite, user-owned collection. Do not paginate
    // the global feed and filter each page afterwards: that used the filtered
    // item count as an offset and could repeatedly request the same remote
    // page, leaving the footer spinner on forever.
    final query = filter.query?.trim().toLowerCase();
    final favorites = await ref.read(favoritesProvider.future);
    final items = favorites.where((publication) {
      final matchesSection =
          filter.sectionId == null ||
          publication.primarySectionId == filter.sectionId;
      final matchesQuery =
          query == null ||
          query.isEmpty ||
          publication.title.toLowerCase().contains(query);
      return matchesSection && matchesQuery;
    }).toList();
    return PublicationsPage(items: items, hasMore: false);
  }

  /// Pull-to-refresh: keeps showing current content while a fresh first page
  /// loads, then swaps it in.
  Future<void> refresh() async {
    await _loadFirstPage(_currentFilter());
  }

  _PublicationsFilter _currentFilter() {
    final search = ref.read(searchQueryProvider);
    final selected = ref.read(selectedSectionProvider);
    return _PublicationsFilter(
      sectionId: selected?.id,
      query: search.isEmpty ? null : search,
      favoritesOnly: ref.read(favoritesFilterProvider),
    );
  }

  /// Appends the next page of publications. A concurrent call while a load is
  /// in flight is ignored.
  Future<void> loadMore() async {
    if (_loadMoreInFlight) return;
    final current = state;
    if (current is! AsyncData<PublicationsPage>) return;
    final page = current.value;
    if (!page.hasMore) return;

    final filter = _currentFilter();
    // Favorites are deliberately a single, finite page (see
    // [_loadFavoritesPage]), including when their cards do not fill the view.
    if (filter.favoritesOnly) return;

    final requestGeneration = _requestGeneration;
    _loadMoreInFlight = true;
    state = AsyncData(
      PublicationsPage(
        items: page.items,
        hasMore: page.hasMore,
        isLoadingMore: true,
      ),
    );
    try {
      final next = await ref.read(getPublicationsWithFiltersProvider)(
        sectionId: filter.sectionId,
        searchQuery: filter.query,
        limit: kMainPageSize,
        offset: page.items.length,
      );
      final merged = [...page.items, ...next];
      if (ref.mounted && requestGeneration == _requestGeneration) {
        _cached = PublicationsPage(
          items: merged,
          hasMore: next.length >= kMainPageSize,
        );
        state = AsyncData(_cached!);
      }
    } catch (error) {
      if (ref.mounted && requestGeneration == _requestGeneration) {
        // Keep the already loaded cards available, but leave the loading
        // state. The UI exposes a retry instead of an indefinite spinner.
        state = AsyncData(
          PublicationsPage(
            items: page.items,
            hasMore: page.hasMore,
            loadMoreError: error,
          ),
        );
      }
    } finally {
      if (requestGeneration == _requestGeneration) {
        _loadMoreInFlight = false;
      }
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
final filteredPublicationsProvider = Provider<AsyncValue<List<Publication>>>((
  ref,
) {
  final async = ref.watch(mainPublicationsProvider);
  return async.when(
    data: (page) => AsyncData(page.items),
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});
