import 'package:hive/hive.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';

/// Thin wrapper around the `favorites` Hive box: publication id -> true.
class FavoritesLocalDataSource {
  Box<bool> get _box => LocalStorageService.favoritesBox;

  List<String> getFavoriteIds() => _box.keys.cast<String>().toList();

  bool isFavorite(String publicationId) => _box.containsKey(publicationId);

  Future<void> addFavorite(String publicationId) =>
      _box.put(publicationId, true);

  Future<void> removeFavorite(String publicationId) =>
      _box.delete(publicationId);
}
