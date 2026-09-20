import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_publication_detail.dart';

/// (De)serialises an [OfflinePublicationDetail] to/from a JSON-friendly map.
///
/// Pure (no io/network) so it can be round-trip tested in isolation.
Map<String, dynamic> offlineDetailToSnapshot(OfflinePublicationDetail detail) {
  final p = detail.publication;
  final publicationJson = <String, dynamic>{
    'id': p.id,
    'title': p.title,
    'icon': p.icon,
    'publishedAt': p.publishedAt.toIso8601String(),
    'createdAt': p.createdAt.toIso8601String(),
    'updatedAt': p.updatedAt.toIso8601String(),
    'type': p.type,
    'status': p.status,
    'primarySectionId': p.primarySectionId,
    'photoPath': p.photoPath,
    'hasAdditionalSections': p.hasAdditionalSections,
  };

  return {
    'publication': publicationJson,
    'blocks': detail.blocks.map(_blockToJson).toList(),
    'sectionIds': detail.sectionIds,
    'mediaFiles': detail.mediaFiles,
    'hasOnlineVideo': detail.hasOnlineVideo,
  };
}

OfflinePublicationDetail offlineDetailFromSnapshot(Map<String, dynamic> map) {
  final publicationJson =
      (map['publication'] as Map?)?.cast<String, dynamic>() ?? const {};

  DateTime parseDate(String key) {
    final v = publicationJson[key];
    return v is String ? DateTime.parse(v).toLocal() : DateTime.now();
  }

  final publication = Publication(
    id: publicationJson['id'] as String? ?? '',
    title: publicationJson['title'] as String? ?? '',
    icon: publicationJson['icon'] as String?,
    publishedAt: parseDate('publishedAt'),
    createdAt: parseDate('createdAt'),
    updatedAt: parseDate('updatedAt'),
    type: publicationJson['type'] as String? ?? 'article',
    status: publicationJson['status'] as String?,
    primarySectionId: publicationJson['primarySectionId'] as String? ?? '',
    photoPath: publicationJson['photoPath'] as String?,
    hasAdditionalSections:
        publicationJson['hasAdditionalSections'] as bool? ?? false,
  );

  final rawBlocks = (map['blocks'] as List?) ?? const [];
  final blocks = rawBlocks
      .whereType<Map>()
      .map((b) => _blockFromJson((b as Map).cast<String, dynamic>()))
      .toList();

  return OfflinePublicationDetail(
    publication: publication,
    blocks: blocks,
    sectionIds: (map['sectionIds'] as List?)?.cast<String>() ?? const [],
    mediaFiles:
        (map['mediaFiles'] as Map?)?.cast<String, dynamic>().cast<String, String>() ??
        const {},
    hasOnlineVideo: map['hasOnlineVideo'] as bool? ?? false,
  );
}

Map<String, dynamic> _blockToJson(ContentBlock block) {
  switch (block) {
    case TextContentBlock():
      return {
        'type': 'text',
        'id': block.id,
        'publicationId': block.publicationId,
        'orderIndex': block.orderIndex,
        'text': block.text,
      };
    case ImageContentBlock():
      return {
        'type': 'image',
        'id': block.id,
        'publicationId': block.publicationId,
        'orderIndex': block.orderIndex,
        'imagePaths': block.imagePaths,
      };
    case VideoContentBlock():
      return {
        'type': 'video',
        'id': block.id,
        'publicationId': block.publicationId,
        'orderIndex': block.orderIndex,
        'source': block.source.wireValue,
        'url': block.url,
        'provider': block.provider.wireValue,
        'videoPath': block.videoPath,
        'videoName': block.videoName,
        'videoMime': block.videoMime,
        'videoSize': block.videoSize,
      };
    case FileContentBlock():
      return {
        'type': 'file',
        'id': block.id,
        'publicationId': block.publicationId,
        'orderIndex': block.orderIndex,
        'path': block.path,
        'name': block.name,
        'size': block.size,
        'mimeType': block.mimeType,
      };
    case AudioContentBlock():
      return {
        'type': 'audio',
        'id': block.id,
        'publicationId': block.publicationId,
        'orderIndex': block.orderIndex,
        'source': block.source.wireValue,
        'audioPath': block.audioPath,
        'audioUrl': block.audioUrl,
      };
  }
}

ContentBlock _blockFromJson(Map<String, dynamic> json) {
  final id = json['id'] as String? ?? '';
  final publicationId = json['publicationId'] as String? ?? '';
  final orderIndex = json['orderIndex'] as int? ?? 0;
  final type = json['type'] as String? ?? '';

  switch (type) {
    case 'text':
      return TextContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        text: json['text'] as String? ?? '',
      );
    case 'image':
      return ImageContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        imagePaths: (json['imagePaths'] as List?)?.cast<String>() ?? const [],
      );
    case 'video':
      return VideoContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        source: VideoSourceType.fromWireValue(json['source'] as String? ?? ''),
        url: json['url'] as String? ?? '',
        provider: VideoProviderType.fromWireValue(
          json['provider'] as String? ?? '',
        ),
        videoPath: json['videoPath'] as String?,
        videoName: json['videoName'] as String?,
        videoMime: json['videoMime'] as String?,
        videoSize: json['videoSize'] as int?,
      );
    case 'file':
      return FileContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        path: json['path'] as String? ?? '',
        name: json['name'] as String? ?? '',
        size: json['size'] as int?,
        mimeType: json['mimeType'] as String?,
      );
    case 'audio':
      return AudioContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        source: AudioSourceType.fromWireValue(json['source'] as String? ?? ''),
        audioPath: json['audioPath'] as String?,
        audioUrl: json['audioUrl'] as String?,
      );
    default:
      return TextContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        text: '',
      );
  }
}