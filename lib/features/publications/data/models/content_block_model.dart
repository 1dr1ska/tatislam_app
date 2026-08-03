import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

/// We use a flat JSONB `data` column holding a single key-value pair per block
/// type (e.g. `{"text": "..."}` or `{"path": "blocks/...jpg"}`).
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
          imagePath: data['path'] as String? ?? '',
        ),
      _typeVideo => VideoContentBlock(
          id: id,
          publicationId: publicationId,
          orderIndex: orderIndex,
          url: data['url'] as String? ?? '',
          provider: VideoProviderType.values.firstWhere(
            (v) => v.name == data['provider'],
            orElse: () => VideoProviderType.rutube,
          ),
        ),
      _typeAudio => AudioContentBlock(
          id: id,
          publicationId: publicationId,
          orderIndex: orderIndex,
          source: AudioSourceType.values.firstWhere(
            (v) => v.name == data['source'],
            orElse: () => AudioSourceType.upload,
          ),
          audioPath: data['audio_path'] as String?,
          audioUrl: data['audio_url'] as String?,
        ),
      _ => throw ArgumentError('Unknown content block type: $type'),
    };
  }

  /// Serialises a single [ContentBlock] into the JSONB `data` column value.
  static Map<String, dynamic> _dataOf(ContentBlock block) {
    return switch (block) {
      TextContentBlock(text: final text) => {'text': text},
      ImageContentBlock(imagePath: final path) => {'path': path},
      VideoContentBlock(url: final url, provider: final provider) =>
        {'url': url, 'provider': provider.name},
      AudioContentBlock(
        source: final source,
        audioPath: final audioPath,
        audioUrl: final audioUrl,
      ) =>
        {
          'source': source.name,
          'audio_path': ?audioPath,
          'audio_url': ?audioUrl,
        },
    };
  }

  /// Builds a map suitable for Supabase insert/update.
  ///
  /// The `id` column is omitted so the DB auto-generates a UUID. The caller
  /// can upsert existing blocks (kept id) alongside new ones (fresh uuid).
  static Map<String, dynamic> toInsertJson(
      ContentBlock block, String publicationId) {
    return {
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
    };
  }
}