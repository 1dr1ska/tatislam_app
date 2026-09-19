import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';

/// We use a flat JSONB `data` column holding a single key-value pair per block
/// type (e.g. `{"text": "..."}` or `{"paths": ["blocks/...jpg", ...]}`).
///
/// Image blocks store an ordered list of Storage paths under `paths`. Legacy
/// rows stored a single path under `path` — both are read and kept working;
/// all new writes use `paths`.
///
/// The JSONB is flexible enough that adding a new block type later requires
/// zero schema changes — just a new subclass + case here.
///
/// The `type` column is a string discriminator. The subclasses below are
/// parsed from the same `type` string used in the DB.
///
/// **Important:** the DB stores `type` as a `text` column. We use the same
/// string constants (`_typeText`, `_typeImage`, `_typeVideo`, `_typeAudio`)
/// everywhere — Flutter, SQL, and Supabase functions.
const _typeText = 'text';
const _typeImage = 'image';
const _typeVideo = 'video';
const _typeAudio = 'audio';
const _typeFile = 'file';

/// Maps a `content_blocks` table row to/from a [ContentBlock] sealed class.
class ContentBlockModel {
  /// Parses a single content block from a Supabase row.
  static ContentBlock fromJson(Map<String, dynamic> row) {
    final id = row['id'] as String? ?? '';
    final publicationId = row['publication_id'] as String? ?? '';
    final orderIndex = row['order_index'] as int? ?? 0;
    final type = row['type'] as String? ?? '';
    final data = row['data'] as Map<String, dynamic>? ?? {};

    return switch (type) {
      _typeText => TextContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        text: data['text'] as String? ?? '',
      ),
      _typeImage => ImageContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        imagePaths: _imagePathsOf(data),
      ),
      _typeVideo => VideoContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        source: VideoSourceType.values.firstWhere(
          (v) => v.name == data['source'],
          orElse: () => VideoSourceType.external,
        ),
        url: data['url'] as String? ?? '',
        provider: VideoProviderType.values.firstWhere(
          (v) => v.name == data['provider'],
          orElse: () => VideoProviderType.rutube,
        ),
        videoPath: data['path'] as String?,
        videoName: data['name'] as String?,
        videoMime: data['mime'] as String?,
        videoSize: (data['size'] as num?)?.toInt(),
      ),
      _typeAudio => AudioContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        source: AudioSourceType.values.firstWhere(
          (v) => v.name == data['source'],
          orElse: () => AudioSourceType.upload,
        ),
        audioPath: data['path'] as String?,
        audioUrl: data['url'] as String?,
      ),
      _typeFile => FileContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex,
        path: data['path'] as String? ?? '',
        name: data['name'] as String? ?? '',
        size: (data['size'] as num?)?.toInt(),
        mimeType: data['mime'] as String?,
      ),
      _ => throw ArgumentError('Unknown content block type: $type'),
    };
  }

  /// Parses the photo paths of an `image` block from its JSONB `data`.
  ///
  /// Accepts both the new `paths` (ordered list) and the legacy `path` (single
  /// string) formats, so old publications keep working without any migration.
  static List<String> _imagePathsOf(Map<String, dynamic> data) {
    final paths = data['paths'];
    if (paths is List) {
      final result = <String>[];
      for (final value in paths) {
        final path = value as String?;
        if (path != null && path.isNotEmpty) result.add(path);
      }
      if (result.isNotEmpty) return result;
    }
    final legacy = data['path'] as String?;
    if (legacy != null && legacy.isNotEmpty) return [legacy];
    return const <String>[];
  }

  /// Serialises a single [ContentBlock] into the JSONB `data` column value.
  static Map<String, dynamic> _dataOf(ContentBlock block) {
    return switch (block) {
      TextContentBlock(text: final text) => {'text': text},
      ImageContentBlock(imagePaths: final paths) => {
        // New canonical format: an ordered list. Legacy single-photo rows keep
        // using `path` — the reader above accepts both.
        'paths': paths.where((path) => path.isNotEmpty).toList(),
      },
      VideoContentBlock(
        source: final source,
        url: final url,
        provider: final provider,
        videoPath: final videoPath,
        videoName: final videoName,
        videoMime: final videoMime,
        videoSize: final videoSize,
      ) => {
        'source': source.name,
        if (source == VideoSourceType.external) 'url': url,
        if (source == VideoSourceType.external) 'provider': provider.name,
        if (source == VideoSourceType.upload && videoPath != null) 'path': videoPath,
        if (videoName != null && videoName.isNotEmpty) 'name': videoName,
        'mime': ?videoMime,
        'size': ?videoSize,
      },
      AudioContentBlock(
        source: final source,
        audioPath: final audioPath,
        audioUrl: final audioUrl,
      ) =>
        {
          'source': source.name,
          'path': ?audioPath,
          'url': ?audioUrl,
        },
      FileContentBlock(
        path: final path,
        name: final name,
        size: final size,
        mimeType: final mimeType,
      ) => {
        'path': path,
        if (name.isNotEmpty) 'name': name,
        'size': ?size,
        'mime': ?mimeType,
      },
    };
  }

  /// Builds a map suitable for Supabase insert/update.
  ///
  /// The block `id` is preserved so callers can upsert by it; new blocks get
  /// a fresh uuid at creation time.
  static Map<String, dynamic> toInsertJson(
    ContentBlock block,
    String publicationId,
  ) {
    return {
      'id': block.id,
      'publication_id': publicationId,
      'type': _typeOf(block),
      'order_index': block.orderIndex,
      'data': _dataOf(block),
    };
  }

  /// Returns the DB `type` string for a [ContentBlock] subclass.
  static String _typeOf(ContentBlock block) {
    return switch (block) {
      TextContentBlock() => _typeText,
      ImageContentBlock() => _typeImage,
      VideoContentBlock() => _typeVideo,
      AudioContentBlock() => _typeAudio,
      FileContentBlock() => _typeFile,
    };
  }
}
