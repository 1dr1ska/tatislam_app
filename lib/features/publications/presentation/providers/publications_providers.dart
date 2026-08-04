import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/sections/presentation/providers/selected_section_provider.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';

/// Current search query text (updated immediately on every keystroke).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Whether to show only favorites.
final favoritesFilterProvider = StateProvider<bool>((ref) => false);

/// Toggle favorites filter on/off.
final toggleFavoritesFilterProvider = Provider<void Function()>((ref) {
  return () {
    final current = ref.read(favoritesFilterProvider);
    ref.read(favoritesFilterProvider.notifier).state = !current;
  };
});

/// Main publications provider — network-only.
final mainPublicationsProvider = FutureProvider<List<Publication>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final selectedSection = ref.watch(selectedSectionProvider);
  final showFavoritesOnly = ref.watch(favoritesFilterProvider);

  final publications = await ref.watch(getPublicationsWithFiltersProvider)(
    sectionId: selectedSection?.id,
    searchQuery: query.isEmpty ? null : query,
  );

  // Apply favorites filter (client-side)
  if (showFavoritesOnly) {
    final favorites = await ref.watch(favoritesProvider.future);
    final favoriteIds = favorites.map((p) => p.id).toSet();
    return publications.where((p) => favoriteIds.contains(p.id)).toList();
  }

  return publications;
});

/// Filtered publications — kept for API compatibility, simply returns
/// [mainPublicationsProvider] since offline filter is removed.
final filteredPublicationsProvider = Provider<AsyncValue<List<Publication>>>((
  ref,
) {
  return ref.watch(mainPublicationsProvider);
});
