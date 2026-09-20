import 'package:hive/hive.dart';
import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/saved_publication_record.dart';

/// Thin wrapper around the `saved_publications` Hive box.
///
/// Stores only the lightweight registry entries (metadata + status + total
/// size) used to render the saved-only list offline; the actual content
/// snapshot lives on the filesystem and is handled by the io repository.
class LocalSavedPublicationDataSource {
  Box<dynamic> get _box => LocalStorageService.savedPublicationsBox;

  Map<String, SavedPublicationRecord> readAll() {
    final result = <String, SavedPublicationRecord>{};
    for (final entry in _box.toMap().entries) {
      final value = entry.value;
      if (value is Map) {
        result[entry.key.toString()] =
            savedPublicationRecordFromMap(
              (value as Map).cast<String, dynamic>(),
            );
      }
    }
    return result;
  }

  SavedPublicationRecord? readOne(String publicationId) {
    final raw = _box.get(publicationId);
    if (raw is! Map) return null;
    return savedPublicationRecordFromMap(
      (raw as Map).cast<String, dynamic>(),
    );
  }

  Future<void> put(SavedPublicationRecord record) =>
      _box.put(record.publicationId, savedPublicationRecordToMap(record));

  Future<void> delete(String publicationId) => _box.delete(publicationId);
}

DownloadStatus downloadStatusFromName(String name) {
  for (final status in DownloadStatus.values) {
    if (status.name == name) return status;
  }
  return DownloadStatus.notSaved;
}

Map<String, dynamic> savedPublicationRecordToMap(SavedPublicationRecord record) {
  final p = record.publication;
  return {
    'publicationId': record.publicationId,
    'savedAt': record.savedAt.millisecondsSinceEpoch,
    'status': record.status.name,
    'totalBytes': record.totalBytes,
    'hasOnlineVideo': record.hasOnlineVideo,
    'publication': {
      'id': p.id,
      'title': p.title,
      'icon': p.icon,
      'publishedAt': p.publishedAt.millisecondsSinceEpoch,
      'createdAt': p.createdAt.millisecondsSinceEpoch,
      'updatedAt': p.updatedAt.millisecondsSinceEpoch,
      'type': p.type,
      'status': p.status,
      'primarySectionId': p.primarySectionId,
      'photoPath': p.photoPath,
      'hasAdditionalSections': p.hasAdditionalSections,
    },
  };
}

SavedPublicationRecord savedPublicationRecordFromMap(Map<String, dynamic> raw) {
  final publication = (raw['publication'] as Map?)?.cast<String, dynamic>();

  DateTime parseDate(String key, DateTime fallback) {
    final v = publication?[key];
    return v is int
        ? DateTime.fromMillisecondsSinceEpoch(v)
        : fallback;
  }

  final publicationEntity = Publication(
    id:
        publication?['id'] as String? ??
        raw['publicationId'] as String? ??
        '',
    title: publication?['title'] as String? ?? '',
    icon: publication?['icon'] as String?,
    publishedAt: parseDate('publishedAt', DateTime.now()),
    createdAt: parseDate('createdAt', DateTime.now()),
    updatedAt: parseDate('updatedAt', DateTime.now()),
    type: publication?['type'] as String? ?? 'article',
    status: publication?['status'] as String?,
    primarySectionId: publication?['primarySectionId'] as String? ?? '',
    photoPath: publication?['photoPath'] as String?,
    hasAdditionalSections:
        publication?['hasAdditionalSections'] as bool? ?? false,
  );

  return SavedPublicationRecord(
    publicationId: raw['publicationId'] as String? ?? '',
    savedAt: DateTime.fromMillisecondsSinceEpoch(
      raw['savedAt'] is int ? raw['savedAt'] as int : 0,
    ),
    status: downloadStatusFromName(raw['status'] as String? ?? ''),
    totalBytes: raw['totalBytes'] as int?,
    publication: publicationEntity,
    hasOnlineVideo: raw['hasOnlineVideo'] as bool? ?? false,
  );
}