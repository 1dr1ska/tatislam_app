import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_size_info.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/saved_publication_record.dart';

/// Persistence + orchestration for the "saved publications" (offline) feature.
abstract class SavedPublicationRepository {
  /// All saved publication registries, most-recently-saved first. Offline-safe.
  Future<List<SavedPublicationRecord>> getSaved();

  /// The registry entry for [publicationId], or null when never saved.
  Future<SavedPublicationRecord?> getById(String publicationId);

  /// True when the offline copy is complete *and* present on device, so the
  /// UI can show a filled "saved" icon (and disable re-download).
  Future<bool> isFullySaved(String publicationId);

  /// Estimates the size / content breakdown shown in the confirmation dialog.
  ///
  /// Heads each downloadable resource to read its `Content-Length`. Any
  /// resource without a known length (or a failed HEAD) marks the total as
  /// unknown.
  Future<DownloadSizeInfo> computeSize(PublicationDetail detail);

  /// Downloads every supported resource of [publicationId] and persists the
  /// offline snapshot. Reports progress through [onProgress].
  ///
  /// Throws on failure/cancellation; partial files are cleaned up before
  /// throwing so no corrupt copy survives.
  Future<void> save(
    String publicationId, {
    void Function(DownloadProgress progress)? onProgress,
    SavingCancelSignal? cancelSignal,
  });

  /// Reads back the complete offline copy, or null when not saved.
  Future<OfflinePublicationDetail?> getOfflineDetail(String publicationId);

  /// Deletes the offline copy (directory + registry entry).
  Future<void> remove(String publicationId);
}