import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/core/services/supabase_service.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/features/publications/data/datasources/publication_remote_data_source.dart';
import 'package:tatislam_app/features/publications/data/repositories/publication_repository_impl.dart';
import 'package:tatislam_app/features/publications/domain/repositories/publication_repository.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

final publicationRemoteDataSourceProvider = Provider<PublicationRemoteDataSource>((ref) {
  return PublicationRemoteDataSource(SupabaseService.client);
});

final publicationRepositoryProvider = Provider<PublicationRepository>((ref) {
  return PublicationRepositoryImpl(
    ref.watch(publicationRemoteDataSourceProvider),
    ref.watch(mediaStorageRepositoryProvider),
  );
});

/// Provider for getting publications
final getPublicationsProvider = Provider<Future<List<Publication>> Function({bool includeAllStatuses})>(
  (ref) {
    final repository = ref.watch(publicationRepositoryProvider);
    return ({bool includeAllStatuses = false}) => repository.getPublications(includeAllStatuses: includeAllStatuses);
  },
);

/// Provider for getting publications with filters
final getPublicationsWithFiltersProvider = Provider<Future<List<Publication>> Function({String? sectionId, String? searchQuery, String? type, int limit, int offset, bool includeAllStatuses})>(
  (ref) {
    final repository = ref.watch(publicationRepositoryProvider);
    return ({String? sectionId, String? searchQuery, String? type, int limit = 20, int offset = 0, bool includeAllStatuses = false}) => 
      repository.getPublications(
        sectionId: sectionId,
        searchQuery: searchQuery,
        type: type,
        limit: limit,
        offset: offset,
        includeAllStatuses: includeAllStatuses,
      );
  },
);

/// Provider for searching publications
final searchPublicationsProvider = Provider<Future<List<Publication>> Function(String query, {bool includeAllStatuses})>(
  (ref) {
    final repository = ref.watch(publicationRepositoryProvider);
    return (query, {bool includeAllStatuses = false}) => repository.getPublications(searchQuery: query, includeAllStatuses: includeAllStatuses);
  },
);

/// Provider for getting publications by IDs
final getPublicationsByIdsProvider = Provider<Future<List<Publication>> Function(List<String> ids)>(
  (ref) {
    final repository = ref.watch(publicationRepositoryProvider);
    return (ids) => repository.getPublicationsByIds(ids);
  },
);
