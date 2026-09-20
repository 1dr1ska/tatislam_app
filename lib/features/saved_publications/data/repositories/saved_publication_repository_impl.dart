import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication_detail.dart';
import 'package:tatislam_app/features/publications/domain/repositories/publication_repository.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/saved_publications/data/datasources/local_saved_publication_data_source.dart';
import 'package:tatislam_app/features/saved_publications/data/datasources/saved_publication_snapshot_codec.dart';
import 'package:tatislam_app/features/saved_publications/data/services/saved_resource_downloader.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_size_info.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_publication_detail.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_plan.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/saved_publication_record.dart';
import 'package:tatislam_app/features/saved_publications/domain/repositories/saved_publication_repository.dart';

/// Resolves the application base directory (overrideable for tests).
typedef AppBaseDirectoryProvider = Future<Directory> Function();

/// Default base directory for saved copies: `<AppSupport>/saved_publications`.
Future<Directory> defaultBaseDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}${Platform.pathSeparator}saved_publications');
}

/// On-device implementation of [SavedPublicationRepository].
///
/// Uses a plain filesystem layout under the app-support directory:
///
/// ```text
/// saved_publications/
///   <publicationId>/
///     publication.json        # snapshot (publication + blocks + media map)
///     images/  audio/  files/ # downloaded resources (skipped when present)
/// ```
///
/// Metadata registries live in the `saved_publications` Hive box (via
/// [LocalSavedPublicationDataSource]) so the home screen can list offline
/// publications without reading back snapshots.
class SavedPublicationRepositoryImpl implements SavedPublicationRepository {
  final LocalSavedPublicationDataSource _dataSource;
  final PublicationRepository _publicationRepository;
  final MediaStorageRepository _mediaStorage;
  final DownloadFile _downloadFile;
  final HeadFile _headFile;
  final AppBaseDirectoryProvider _baseDirectoryProvider;

  SavedPublicationRepositoryImpl({
    required LocalSavedPublicationDataSource dataSource,
    required PublicationRepository publicationRepository,
    required MediaStorageRepository mediaStorage,
    DownloadFile? downloadFile,
    HeadFile? headFile,
    AppBaseDirectoryProvider? baseDirectoryProvider,
  }) : _dataSource = dataSource,
       _publicationRepository = publicationRepository,
       _mediaStorage = mediaStorage,
       _downloadFile = downloadFile ?? _defaults.downloadFile,
       _headFile = headFile ?? _defaults.headFile,
       _baseDirectoryProvider = baseDirectoryProvider ?? defaultBaseDirectory;

  static final _defaults = (() {
    final dio = Dio();
    return (
      downloadFile: dioDownloadFile(dio),
      headFile: dioHeadFile(dio),
    );
  })();

  Future<Directory> _directoryFor(String id) async {
    final base = await _baseDirectoryProvider();
    return Directory('${base.path}${Platform.pathSeparator}$id');
  }

  String _publicUrl(DownloadResource r) =>
      r.storagePath.isNotEmpty ? _mediaStorage.publicUrlFor(r.storagePath) : r.externalUrl;

  /// Local `file://` URI for a downloaded resource.
  String _localUri(File file) => Uri.file(file.path).toString();

  @override
  Future<List<SavedPublicationRecord>> getSaved() async {
    final records = _dataSource.readAll().values.toList()
      ..removeWhere((r) => r.status != DownloadStatus.saved)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return records;
  }

  @override
  Future<SavedPublicationRecord?> getById(String publicationId) async {
    final record = _dataSource.readOne(publicationId);
    if (record == null) return null;
    // A stale record (files deleted meanwhile) should not count as saved.
    if (record.status == DownloadStatus.saved && !(await isFullySaved(publicationId))) {
      return null;
    }
    return record;
  }

  @override
  Future<bool> isFullySaved(String publicationId) async {
    final record = _dataSource.readOne(publicationId);
    if (record == null || record.status != DownloadStatus.saved) return false;
    final dir = await _directoryFor(publicationId);
    final snapshot = File('${dir.path}${Platform.pathSeparator}publication.json');
    return await snapshot.exists();
  }

  @override
  Future<DownloadSizeInfo> computeSize(PublicationDetail detail) async {
    final plan = buildOfflinePlan(detail.blocks);
    var total = 0;
    var unknown = false;

    for (final resource in plan.resources) {
      final url = _publicUrl(resource);
      var size = resource.knownBytes;
      if (size == null) {
        try {
          size = await _headFile(url);
        } catch (_) {
          size = null;
        }
      }
      if (size == null) {
        unknown = true;
      } else {
        total += size;
      }
    }

    return DownloadSizeInfo(
      totalBytes: unknown ? null : total,
      hasUnknownSize: unknown,
      hasOnlineVideo: plan.hasOnlineVideo,
      hasImage: plan.hasImage,
      hasAudio: plan.hasAudio,
      hasFile: plan.hasFile,
      hasVideo: plan.hasVideo,
    );
  }

  @override
  Future<void> save(
    String publicationId, {
    void Function(DownloadProgress progress)? onProgress,
    SavingCancelSignal? cancelSignal,
  }) async {
    final detail = await _publicationRepository.getPublicationDetail(publicationId);
    final plan = buildOfflinePlan(detail.blocks);
    final dir = await _directoryFor(publicationId);
    await dir.create(recursive: true);

    final mediaFiles = <String, String>{};
    var receivedTotal = 0;
    var knownTotal = 0;

    void emit() {
      onProgress?.call(
        DownloadProgress(
          downloadedBytes: receivedTotal,
          totalBytes: knownTotal > 0 ? knownTotal : null,
        ),
      );
    }

    try {
      for (final resource in plan.resources) {
        if (cancelSignal?.isCancelled ?? false) {
          throw SavedDownloadCancelled(publicationId);
        }

        final url = _publicUrl(resource);
        var size = resource.knownBytes;
        if (size == null) {
          try {
            size = await _headFile(url);
          } catch (_) {
            size = null;
          }
        }
        if (size != null) knownTotal += size;

        final kindDir = Directory(
          '${dir.path}${Platform.pathSeparator}${_kindDirName(resource.kind)}',
        );
        await kindDir.create(recursive: true);
        final target = File(
          '${kindDir.path}${Platform.pathSeparator}${resource.targetFileName}',
        );

        if (await target.exists()) {
          receivedTotal += await target.length();
        } else {
          final tmp = File('${target.path}.part');
          if (await tmp.exists()) await tmp.delete();
          var lastForResource = 0;
          final finalSize = await _downloadFile(url, tmp.path,
              onProgress: (received) {
                final delta = received - lastForResource;
                lastForResource = received;
                receivedTotal += delta;
                emit();
              });
          await tmp.rename(target.path);
          // onProgress may not have reached the final byte count; top it up.
          if (finalSize != null && finalSize > lastForResource) {
            receivedTotal += finalSize - lastForResource;
          }
        }

        mediaFiles[resource.source] = _localUri(target);
        emit();
      }

      final offline = OfflinePublicationDetail(
        publication: detail.publication,
        blocks: detail.blocks,
        sectionIds: detail.sectionIds,
        mediaFiles: mediaFiles,
        hasOnlineVideo: plan.hasOnlineVideo,
      );
      final snapshotFile = File(
        '${dir.path}${Platform.pathSeparator}publication.json',
      );
      await snapshotFile.writeAsString(
        jsonEncode(offlineDetailToSnapshot(offline)),
        flush: true,
      );

      await _dataSource.put(
        SavedPublicationRecord(
          publicationId: publicationId,
          savedAt: DateTime.now().toLocal(),
          status: DownloadStatus.saved,
          totalBytes: knownTotal > 0 ? knownTotal : null,
          publication: detail.publication,
          hasOnlineVideo: plan.hasOnlineVideo,
        ),
      );
    } catch (e) {
      // Never leave a half-written / corrupt copy behind.
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  String _kindDirName(String kind) {
    switch (kind) {
      case 'image':
        return 'images';
      case 'video':
        return 'videos';
      default:
        return kind;
    }
  }

  @override
  Future<OfflinePublicationDetail?> getOfflineDetail(String publicationId) async {
    final record = _dataSource.readOne(publicationId);
    if (record == null || record.status != DownloadStatus.saved) return null;

    final dir = await _directoryFor(publicationId);
    final snapshotFile = File(
      '${dir.path}${Platform.pathSeparator}publication.json',
    );
    if (!await snapshotFile.exists()) return null;

    final decoded = jsonDecode(await snapshotFile.readAsString());
    if (decoded is! Map) return null;
    return offlineDetailFromSnapshot((decoded as Map).cast<String, dynamic>());
  }

  @override
  Future<void> remove(String publicationId) async {
    try {
      final dir = await _directoryFor(publicationId);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best-effort filesystem cleanup; the registry entry is removed anyway.
    }
    try {
      await _dataSource.delete(publicationId);
    } catch (_) {}
  }
}

/// App-wiring factory. Tests inject download/head/directory overrides directly
/// through [SavedPublicationRepositoryImpl]'s constructor instead.
SavedPublicationRepository buildSavedPublicationRepository({
  required LocalSavedPublicationDataSource dataSource,
  required PublicationRepository publicationRepository,
  required MediaStorageRepository mediaStorage,
}) {
  return SavedPublicationRepositoryImpl(
    dataSource: dataSource,
    publicationRepository: publicationRepository,
    mediaStorage: mediaStorage,
  );
}