import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';

/// A single remote media resource that must be fetched to produce an offline
/// copy of a publication.
///
/// Images, audio, file/book blocks and uploaded videos reference
/// device-independent storage paths (resolved into download URLs by the data
/// layer). External videos (YouTube / RuTube / direct links) are deliberately
/// NOT downloaded — they are only playable online, so they remain
/// metadata-only.
class DownloadResource {
  /// 'image' | 'audio' | 'file' | 'video'
  final String kind;

  /// Id of the containing [ContentBlock] (guarantees a unique file name).
  final String blockId;

  /// Ordinal of this resource inside its block (0-based).
  final int indexInBlock;

  /// Storage path for app-hosted content ('' for external audio URLs).
  final String storagePath;

  /// Direct http(s) URL for externally hosted audio ('' otherwise).
  final String externalUrl;

  /// Known size in bytes, when the source advertised it (file blocks only).
  final int? knownBytes;

  /// Original file name (for file blocks), otherwise null.
  final String? name;

  const DownloadResource({
    required this.kind,
    required this.blockId,
    required this.indexInBlock,
    this.storagePath = '',
    this.externalUrl = '',
    this.knownBytes,
    this.name,
  });

  /// Non-empty source we eventually download from.
  String get source => storagePath.isNotEmpty ? storagePath : externalUrl;

  /// File extension derived from the source, or a generic fallback per kind.
  String get extension {
    final lastDot = source.lastIndexOf('.');
    if (lastDot >= 0 && lastDot < source.length - 1) {
      final ext = source.substring(lastDot + 1).split('?').first;
      if (ext.isNotEmpty && ext.length <= 8) return ext;
    }
    switch (kind) {
      case 'image':
        return 'jpg';
      case 'audio':
        return 'mp3';
      case 'video':
        return 'mp4';
      default:
        return 'pdf';
    }
  }

  /// Unique, filesystem-safe file name for this resource.
  String get targetFileName => '${blockId}_${indexInBlock}.$extension';
}

/// The set of resources that must be downloaded for one publication, and
/// whether any online-only (video) content is present.
class OfflinePlan {
  final List<DownloadResource> resources;

  /// True when the publication contains at least one video block
  /// (YouTube / RuTube / uploaded) that stays online-only.
  final bool hasOnlineVideo;

  const OfflinePlan({
    required this.resources,
    required this.hasOnlineVideo,
  });

  bool get hasImage => resources.any((r) => r.kind == 'image');
  bool get hasAudio => resources.any((r) => r.kind == 'audio');
  bool get hasFile => resources.any((r) => r.kind == 'file');
  bool get hasVideo => resources.any((r) => r.kind == 'video');
}

/// Plans which remote resources are needed to save [blocks] offline.
///
/// Pure function — no io / network — so it can be unit-tested directly.
/// Uploaded videos are downloaded (they live on the app's own Storage), while
/// externally hosted videos (YouTube / RuTube / direct links) are excluded and
/// only reported via [OfflinePlan.hasOnlineVideo].
OfflinePlan buildOfflinePlan(List<ContentBlock> blocks) {
  final resources = <DownloadResource>[];
  var hasOnlineVideo = false;

  for (final block in blocks) {
    switch (block) {
      case ImageContentBlock(:final id, :final imagePaths):
        for (var i = 0; i < imagePaths.length; i++) {
          resources.add(
            DownloadResource(
              kind: 'image',
              blockId: id,
              indexInBlock: i,
              storagePath: imagePaths[i],
            ),
          );
        }
      case AudioContentBlock(
          :final id,
          :final audioPath,
          :final audioUrl,
        ):
        final hasUpload = audioPath?.isNotEmpty ?? false;
        final hasExternal = audioUrl?.isNotEmpty ?? false;
        if (hasUpload) {
          resources.add(
            DownloadResource(
              kind: 'audio',
              blockId: id,
              indexInBlock: 0,
              storagePath: audioPath!,
              name: audioPath,
            ),
          );
        } else if (hasExternal) {
          resources.add(
            DownloadResource(
              kind: 'audio',
              blockId: id,
              indexInBlock: 0,
              externalUrl: audioUrl!,
              name: audioUrl,
            ),
          );
        }
      case FileContentBlock(
          :final id,
          :final path,
          :final size,
        ):
        final p = path.isEmpty ? '' : path;
        if (p.isEmpty) break;
        resources.add(
          DownloadResource(
            kind: 'file',
            blockId: id,
            indexInBlock: 0,
            storagePath: p,
            knownBytes: size,
            name: _fileNameOf(p),
          ),
        );
      case VideoContentBlock(
          :final id,
          :final source,
          :final videoPath,
          :final videoName,
          :final videoSize,
        ):
        final path = videoPath ?? '';
        if (source == VideoSourceType.upload && path.isNotEmpty) {
          resources.add(
            DownloadResource(
              kind: 'video',
              blockId: id,
              indexInBlock: 0,
              storagePath: path,
              knownBytes: videoSize,
              name: videoName,
            ),
          );
        } else {
          // External (or upload with no path) → online-only.
          hasOnlineVideo = true;
        }
      case TextContentBlock():
        break;
    }
  }

  return OfflinePlan(
    resources: resources,
    hasOnlineVideo: hasOnlineVideo,
  );
}

String _fileNameOf(String path) {
  final segments = path.split('/');
  return segments.isNotEmpty ? segments.last : path;
}