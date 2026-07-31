import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

/// Provider for SearchScreen - provides search results
final searchQueryProvider = StateProvider<String?>((ref) => null);

/// Provider for search results — network-only.
final searchResultsProvider = FutureProvider<List<Publication>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  if (query == null || query.isEmpty) {
    return [];
  }

  final searchPublications = ref.watch(searchPublicationsProvider);
  return await searchPublications(query);
});

/// Provider for searching publications
final searchActionProvider = Provider<Future<void> Function(String query)>((ref) {
  return (query) async {
    ref.read(searchQueryProvider.notifier).state = query;
    ref.invalidate(searchResultsProvider);
  };
});