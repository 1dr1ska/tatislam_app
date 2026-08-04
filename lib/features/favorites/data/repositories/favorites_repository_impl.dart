import 'package:tatislam_app/features/favorites/data/datasources/favorites_local_data_source.dart';
import 'package:tatislam_app/features/favorites/domain/repositories/favorites_repository.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesLocalDataSource _local;

  FavoritesRepositoryImpl(this._local);

  @override
  Future<List<String>> getFavoriteIds() async => _local.getFavoriteIds();

  @override
  Future<bool> isFavorite(String publicationId) async =>
      _local.isFavorite(publicationId);

  @override
  Future<void> addFavorite(String publicationId) =>
      _local.addFavorite(publicationId);

  @override
  Future<void> removeFavorite(String publicationId) =>
      _local.removeFavorite(publicationId);

  @override
  Future<bool> toggleFavorite(String publicationId) async {
    final isCurrentlyFavorite = _local.isFavorite(publicationId);
    if (isCurrentlyFavorite) {
      await _local.removeFavorite(publicationId);
      return false;
    } else {
      await _local.addFavorite(publicationId);
      return true;
    }
  }
}
