import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/publications/domain/repositories/publication_repository.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/saved_publications/data/datasources/local_saved_publication_data_source.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_size_info.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/saved_publication_record.dart';
import 'package:tatislam_app/features/saved_publications/domain/repositories/saved_publication_repository.dart';

/// Web fallback: the browser has no filesystem, so the offline feature is a
/// no-op. The UI disables the "save" affordance on web; this repository just
/// returns "nothing is saved" so nothing crashes.
class UnsupportedSavedPublicationRepository
    implements SavedPublicationRepository {
  const UnsupportedSavedPublicationRepository();

  @override
  Future<List<SavedPublicationRecord>> getSaved() async => const [];

  @override
  Future<SavedPublicationRecord?> getById(String publicationId) async => null;

  @override
  Future<bool> isFullySaved(String publicationId) async => false;

  @override
  Future<DownloadSizeInfo> computeSize(PublicationDetail detail) {
    throw UnsupportedError('Saved publications are not supported on web.');
  }

  @override
  Future<void> save(
    String publicationId, {
    void Function(DownloadProgress progress)? onProgress,
    SavingCancelSignal? cancelSignal,
  }) {
    throw UnsupportedError('Saved publications are not supported on web.');
  }

  @override
  Future<OfflinePublicationDetail?> getOfflineDetail(
    String publicationId,
  ) async => null;

  @override
  Future<void> remove(String publicationId) async {}
}

SavedPublicationRepository buildSavedPublicationRepository({
  required LocalSavedPublicationDataSource dataSource,
  required PublicationRepository publicationRepository,
  required MediaStorageRepository mediaStorage,
}) {
  return const UnsupportedSavedPublicationRepository();
}