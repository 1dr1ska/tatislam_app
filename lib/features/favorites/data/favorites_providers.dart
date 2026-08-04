import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/favorites/data/datasources/favorites_local_data_source.dart';
import 'package:tatislam_app/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:tatislam_app/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

export 'package:tatislam_app/features/publications/data/publication_providers.dart'
    show getPublicationsByIdsProvider;

final favoritesLocalDataSourceProvider = Provider<FavoritesLocalDataSource>((
  ref,
) {
  return FavoritesLocalDataSource();
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepositoryImpl(ref.watch(favoritesLocalDataSourceProvider));
});

/// Provider for getting favorite publications
final getFavoritesProvider = Provider<Future<List<Publication>> Function()>((
  ref,
) {
  return () async {
    final repository = ref.watch(favoritesRepositoryProvider);
    final favoriteIds = await repository.getFavoriteIds();

    if (favoriteIds.isEmpty) return [];

    final getPublicationsByIds = ref.watch(getPublicationsByIdsProvider);
    return await getPublicationsByIds(favoriteIds);
  };
});

/// Provider for removing a favorite
final removeFavoriteProvider =
    Provider<Future<void> Function(String publicationId)>((ref) {
      return (publicationId) async {
        final repository = ref.watch(favoritesRepositoryProvider);
        await repository.removeFavorite(publicationId);
      };
    });
