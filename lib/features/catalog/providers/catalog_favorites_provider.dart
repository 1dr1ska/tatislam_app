import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/favorites/data/favorites_providers.dart';

/// Provider for CatalogScreen - provides favorite publications
final catalogFavoritesProvider = FutureProvider<List<Publication>>((ref) async {
  debugPrint('Catalog Favorites: Starting to fetch favorite publications');
  final getFavorites = ref.watch(getFavoritesProvider);
  final result = await getFavorites();
  debugPrint('Catalog Favorites: Finished fetching favorite publications, count: ${result.length}');
  return result;
});