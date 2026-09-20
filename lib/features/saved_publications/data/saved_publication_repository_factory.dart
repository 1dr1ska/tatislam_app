import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/publications/domain/repositories/publication_repository.dart';
import 'package:tatislam_app/features/saved_publications/data/datasources/local_saved_publication_data_source.dart';
import 'package:tatislam_app/features/saved_publications/data/repositories/saved_publication_repository_impl.dart'
    if (dart.library.js_interop)
    'repositories/saved_publication_repository_unsupported.dart' as impl;
import 'package:tatislam_app/features/saved_publications/domain/repositories/saved_publication_repository.dart';

export 'package:tatislam_app/features/saved_publications/domain/repositories/saved_publication_repository.dart';

/// Builds the platform-appropriate [SavedPublicationRepository].
SavedPublicationRepository buildSavedPublicationRepository({
  required LocalSavedPublicationDataSource dataSource,
  required PublicationRepository publicationRepository,
  required MediaStorageRepository mediaStorage,
}) {
  return impl.buildSavedPublicationRepository(
    dataSource: dataSource,
    publicationRepository: publicationRepository,
    mediaStorage: mediaStorage,
  );
}