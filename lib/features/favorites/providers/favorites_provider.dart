import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/favorites/data/favorites_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

/// Provider for FavoritesScreen - provides favorite publications
final favoritesProvider = FutureProvider<List<Publication>>((ref) async {
  final getFavorites = ref.watch(getFavoritesProvider);
  return await getFavorites();
});

/// Provider for checking if a publication is favorite
final favoritesIsFavoriteProvider = Provider.family<bool, String>((
  ref,
  publicationId,
) {
  final asyncValue = ref.watch(favoritesProvider);

  return asyncValue.when(
    data: (favorites) => favorites.any((p) => p.id == publicationId),
    loading: () => false,
    error: (error, stackTrace) => false,
  );
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
        return await repository.toggleFavorite(publicationId);
      };
    });
