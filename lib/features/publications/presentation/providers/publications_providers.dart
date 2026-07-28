import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/selected_section_provider.dart';
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

/// Main publications provider that combines all filters:
/// search query + section filter + favorites filter.
/// Search and section filters are applied server-side (Supabase query).
/// Favorites filter is applied client-side using the existing [favoritesProvider].
final mainPublicationsProvider = FutureProvider<List<Publication>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final selectedSection = ref.watch(selectedSectionProvider);
  final showFavoritesOnly = ref.watch(favoritesFilterProvider);
  
  final getPublications = ref.watch(getPublicationsWithFiltersProvider);
  
  // Fetch publications from server with all applicable filters
  final publications = await getPublications(
    sectionId: selectedSection?.id,
    searchQuery: query.isEmpty ? null : query,
  );
  
  // If favorites filter is enabled, filter client-side using existing favorites
  if (showFavoritesOnly) {
    final favorites = await ref.watch(favoritesProvider.future);
    final favoriteIds = favorites.map((p) => p.id).toSet();
    return publications.where((p) => favoriteIds.contains(p.id)).toList();
  }
  
  return publications;
});
