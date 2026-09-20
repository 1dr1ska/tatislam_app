import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:tatislam_app/features/publications/data/publication_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/saved_publications/data/datasources/local_saved_publication_data_source.dart';
import 'package:tatislam_app/features/saved_publications/data/saved_publication_repository_factory.dart';
import 'package:tatislam_app/features/saved_publications/data/services/saved_resource_downloader.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/saved_publication_record.dart';
import 'package:tatislam_app/features/saved_publications/presentation/state/saved_publication_state.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';

final savedPublicationLocalDataSourceProvider =
    Provider<LocalSavedPublicationDataSource>((ref) {
      return LocalSavedPublicationDataSource();
    });

final savedPublicationRepositoryProvider =
    Provider<SavedPublicationRepository>((ref) {
      return buildSavedPublicationRepository(
        dataSource: ref.watch(savedPublicationLocalDataSourceProvider),
        publicationRepository: ref.watch(publicationRepositoryProvider),
        mediaStorage: ref.watch(mediaStorageRepositoryProvider),
      );
    });

/// ======================= Filter (saved-only) ========================
final savedPublicationsFilterProvider = StateProvider<bool>((ref) => false);

final toggleSavedPublicationsFilterProvider = Provider<void Function()>((ref) {
  return () {
    final current = ref.read(savedPublicationsFilterProvider);
    ref.read(savedPublicationsFilterProvider.notifier).state = !current;
  };
});

/// ======================= Offline data ========================
/// Publications that are fully saved on-device (for the saved-only filter).
/// Reads only local registries — never the network.
final savedPublicationPublicationsProvider = FutureProvider<List<Publication>>(
  (ref) async {
    final records = await ref.read(savedPublicationRepositoryProvider).getSaved();
    return records.map((r) => r.publication).toList();
  },
);

final savedPublicationsRecordsProvider =
    FutureProvider<List<SavedPublicationRecord>>((ref) {
      return ref.read(savedPublicationRepositoryProvider).getSaved();
    });

/// The complete offline copy of [publicationId], or null when not saved.
final savedPublicationOfflineDetailProvider =
    FutureProvider.family<OfflinePublicationDetail?, String>((ref, id) {
      return ref.read(savedPublicationRepositoryProvider).getOfflineDetail(id);
    });

/// ======================= Per-publication controller ========================
final savedPublicationStateProvider =
    NotifierProvider.family<SavedPublicationController, SavedPublicationState, String>(
      SavedPublicationController.new,
    );

/// Coordinates a single publication's save / cancel / delete lifecycle.
class SavedPublicationController extends Notifier<SavedPublicationState> {
  SavedPublicationController(this.publicationId);

  final String publicationId;

  SavingCancelSignal? _cancel;

  @override
  SavedPublicationState build() {
    // Initial status from the local registry (synchronous Hive read).
    final record = ref
        .read(savedPublicationLocalDataSourceProvider)
        .readOne(publicationId);
    if (record != null && record.status == DownloadStatus.saved) {
      return SavedPublicationState(
        status: DownloadStatus.saved,
        totalBytes: record.totalBytes,
      );
    }
    return const SavedPublicationState();
  }

  /// Starts (or schedules) the offline download and reports progress.
  Future<void> start() async {
    if (state.isDownloading || state.isSaved) return;

    final repo = ref.read(savedPublicationRepositoryProvider);
    final cancel = SavingCancelSignal();
    _cancel = cancel;

    state = state.copyWith(status: DownloadStatus.downloading, progress: null);
    try {
      await repo.save(
        publicationId,
        onProgress: (p) {
          if (ref.mounted) {
            state = state.copyWith(status: DownloadStatus.downloading, progress: p);
          }
        },
        cancelSignal: cancel,
      );
      if (ref.mounted) {
        final total = state.progress?.totalBytes;
        state = SavedPublicationState(
          status: DownloadStatus.saved,
          totalBytes: total,
        );
      }
    } catch (e) {
      if (ref.mounted) {
        state = SavedPublicationState(
          status: e is SavedDownloadCancelled
              ? DownloadStatus.notSaved
              : DownloadStatus.failed,
        );
      }
    } finally {
      _cancel = null;
      if (ref.mounted) {
        ref.invalidate(savedPublicationPublicationsProvider);
        ref.invalidate(savedPublicationsRecordsProvider);
      }
    }
  }

  /// Aborts an in-flight download.
  void cancel() {
    _cancel?.cancel();
  }

  /// Deletes the offline copy and resets to [DownloadStatus.notSaved].
  Future<void> remove() async {
    final repo = ref.read(savedPublicationRepositoryProvider);
    try {
      await repo.remove(publicationId);
    } finally {
      if (ref.mounted) {
        state = const SavedPublicationState();
        ref.invalidate(savedPublicationPublicationsProvider);
        ref.invalidate(savedPublicationsRecordsProvider);
        ref.invalidate(savedPublicationOfflineDetailProvider(publicationId));
      }
    }
  }
}