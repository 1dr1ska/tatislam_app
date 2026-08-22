import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/favorites/data/favorites_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

/// Provider for FavoritesScreen - provides favorite publications
final favoritesProvider = FutureProvider<List<Publication>>((ref) async {
  final getFavorites = ref.watch(getFavoritesProvider);
  return await getFavorites();
});

/// Provider for checking if a publication is a favorite.
/// Backed by the local Hive store so cards can render the star instantly
/// without triggering a network fetch of every favorite's metadata on the
/// home screen.
final favoritesIsFavoriteProvider = Provider.family<bool, String>((
  ref,
  publicationId,
) {
  return ref
      .watch(favoritesLocalDataSourceProvider)
      .isFavorite(publicationId);
});

/// Provider for refreshing favorites
final refreshFavoritesProvider = Provider<Future<void> Function()>((ref) {
  final getFavorites = ref.watch(getFavoritesProvider);

  return () async {
    await getFavorites();
    ref.invalidate(favoritesProvider);
  };
});

/// Provider for toggling favorite status
final toggleFavoriteProvider =
    Provider<Future<bool> Function(String publicationId)>((ref) {
      return (publicationId) async {
        final repository = ref.watch(favoritesRepositoryProvider);
        final result = await repository.toggleFavorite(publicationId);
        // The local star provider is sync Hive-backed — invalidate it (and the
        // aggregated favorites provider) so every listener rebuilds.
        ref.invalidate(favoritesIsFavoriteProvider);
        ref.invalidate(favoritesProvider);
        return result;
      };
    });
