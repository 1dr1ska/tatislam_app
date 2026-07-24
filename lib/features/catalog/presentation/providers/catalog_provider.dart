import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';

/// Provider for CatalogScreen - provides all publications
final catalogPublicationsProvider = FutureProvider<List<Publication>>((ref) async {
  debugPrint('Catalog: Starting to fetch publications');
  final getPublications = ref.watch(getPublicationsProvider);
  final result = await getPublications();
  debugPrint('Catalog: Finished fetching publications, count: ${result.length}');
  return result;
});

/// Provider for filtering publications by type
final catalogPublicationsByTypeProvider = Provider.family<List<Publication>, String>((ref, type) {
  final asyncValue = ref.watch(catalogPublicationsProvider);

  return asyncValue.when(
    data: (publications) => publications.where((p) => p.type == type).toList(),
    loading: () => [],
    error: (_, _) => [],
  );
});

/// Provider for refreshing catalog publications
final refreshCatalogPublicationsProvider = Provider<Future<void> Function()>((ref) {
  final getPublications = ref.watch(getPublicationsProvider);

  return () async {
    await getPublications();
    ref.invalidate(catalogPublicationsProvider);
  };
});