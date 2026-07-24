/// Favorites are intentionally device-local only (no Supabase table) —
/// they're a personal reading-list feature, not shared content, so this
/// keeps the backend free of a table that would otherwise need per-user
/// RLS just for a boolean flag.
abstract class FavoritesRepository {
  Future<List<String>> getFavoriteIds();

  Future<bool> isFavorite(String publicationId);

  Future<void> addFavorite(String publicationId);

  Future<void> removeFavorite(String publicationId);

  /// Returns the new favorited state.
  Future<bool> toggleFavorite(String publicationId);
}
