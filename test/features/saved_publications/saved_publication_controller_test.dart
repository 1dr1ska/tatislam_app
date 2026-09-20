import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/data/datasources/local_saved_publication_data_source.dart';
import 'package:tatislam_app/features/saved_publications/data/services/saved_resource_downloader.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_size_info.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/domain/repositories/saved_publication_repository.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/saved_publication_record.dart';
import 'package:tatislam_app/features/saved_publications/presentation/providers/saved_publications_providers.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

/// A [LocalSavedPublicationDataSource] that never touches the Hive box.
///
/// [readOne] is the only method used by the controller's `build`, so the
/// rest is left at the base implementation.
class _MemorySavedDataSource extends LocalSavedPublicationDataSource {
  _MemorySavedDataSource(this._records);

  final Map<String, SavedPublicationRecord> _records;

  @override
  SavedPublicationRecord? readOne(String publicationId) => _records[publicationId];
}

/// Configurable fake for [SavedPublicationRepository].
class _FakeSavedPublicationRepository implements SavedPublicationRepository {
  /// Behaviour of the next `save` call:
  /// - `null`        → succeeds and reports progress.
  /// - `SavedDownloadCancelled` → fails as a cancellation.
  /// - any [Exception] → fails generically.
  Object? saveError;

  int saveCalls = 0;
  int removeCalls = 0;
  String? lastRemovedId;

  @override
  Future<void> save(
    String publicationId, {
    void Function(DownloadProgress progress)? onProgress,
    SavingCancelSignal? cancelSignal,
  }) async {
    saveCalls++;
    if (saveError != null) {
      throw saveError!;
    }
    onProgress?.call(
      const DownloadProgress(downloadedBytes: 128, totalBytes: 500),
    );
    onProgress?.call(
      const DownloadProgress(downloadedBytes: 500, totalBytes: 500),
    );
  }

  @override
  Future<void> remove(String publicationId) async {
    removeCalls++;
    lastRemovedId = publicationId;
  }

  @override
  Future<List<SavedPublicationRecord>> getSaved() async => [];

  @override
  Future<SavedPublicationRecord?> getById(String publicationId) async => null;

  @override
  Future<bool> isFullySaved(String publicationId) async => false;

  @override
  Future<DownloadSizeInfo> computeSize(PublicationDetail detail) {
    throw UnimplementedError();
  }

  @override
  Future<OfflinePublicationDetail?> getOfflineDetail(String publicationId) async =>
      null;
}

void main() {
  ProviderContainer makeContainer({
    required _FakeSavedPublicationRepository repo,
    Map<String, SavedPublicationRecord> seed = const {},
  }) {
    final container = ProviderContainer(
      overrides: [
        savedPublicationRepositoryProvider.overrideWithValue(repo),
        savedPublicationLocalDataSourceProvider.overrideWithValue(
          _MemorySavedDataSource(seed),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('start() transitions notSaved → downloading → saved with total bytes',
      () async {
    final repo = _FakeSavedPublicationRepository();
    final container = makeContainer(repo: repo);

    final stateProvider = savedPublicationStateProvider('p1');
    expect(container.read(stateProvider).status, DownloadStatus.notSaved);

    final controller = container.read(stateProvider.notifier);
    final downloadFuture = controller.start();

    // Mid-flight the state should report downloading (with the latest progress).
    expect(container.read(stateProvider).status, DownloadStatus.downloading);
    expect(
      container.read(stateProvider).progress?.totalBytes,
      500,
    );

    await downloadFuture;
    expect(container.read(stateProvider).status, DownloadStatus.saved);
    expect(container.read(stateProvider).totalBytes, 500);
    expect(repo.saveCalls, 1);
  });

  test('start() ignores repeated calls while downloading or already saved',
      () async {
    final repo = _FakeSavedPublicationRepository();
    final container = makeContainer(repo: repo);

    final stateProvider = savedPublicationStateProvider('p2');
    final controller = container.read(stateProvider.notifier);
    final first = controller.start();
    // A second call right away must be a no-op (already downloading).
    await controller.start();
    await first;

    expect(repo.saveCalls, 1);
    expect(container.read(stateProvider).status, DownloadStatus.saved);

    // Now that it's saved, starting again must also be a no-op.
    await controller.start();
    expect(repo.saveCalls, 1);
  });

  test('start() maps a cancellation to notSaved via cancel()', () async {
    final repo = _FakeSavedPublicationRepository()
      ..saveError = SavedDownloadCancelled('p3');
    final container = makeContainer(repo: repo);

    final stateProvider = savedPublicationStateProvider('p3');
    final controller = container.read(stateProvider.notifier);
    await controller.start();

    expect(container.read(stateProvider).status, DownloadStatus.notSaved);

    // cancel() on a non-in-flight controller is a safe no-op.
    controller.cancel();
    expect(container.read(stateProvider).status, DownloadStatus.notSaved);
  });

  test('start() maps a generic failure to failed', () async {
    final repo = _FakeSavedPublicationRepository()
      ..saveError = StateError('network down');
    final container = makeContainer(repo: repo);

    final stateProvider = savedPublicationStateProvider('p4');
    await container.read(stateProvider.notifier).start();

    expect(container.read(stateProvider).status, DownloadStatus.failed);
  });

  test('remove() resets a saved publication to notSaved', () async {
    final repo = _FakeSavedPublicationRepository();
    final savedRecord = SavedPublicationRecord(
      publicationId: 'p5',
      savedAt: DateTime(2026, 1, 1),
      status: DownloadStatus.saved,
      totalBytes: 500,
      publication: Publication(
        id: 'p5',
        title: 'Тест',
        publishedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        type: 'article',
        primarySectionId: 'sec1',
      ),
      hasOnlineVideo: false,
    );
    final container = makeContainer(
      repo: repo,
      seed: {'p5': savedRecord},
    );

    final stateProvider = savedPublicationStateProvider('p5');
    expect(container.read(stateProvider).status, DownloadStatus.saved);

    await container.read(stateProvider.notifier).remove();

    expect(repo.removeCalls, 1);
    expect(repo.lastRemovedId, 'p5');
    expect(container.read(stateProvider).status, DownloadStatus.notSaved);
  });
}