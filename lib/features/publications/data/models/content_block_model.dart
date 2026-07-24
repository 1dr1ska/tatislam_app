import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

/// Maps a `content_blocks` row (`type` + `data jsonb`) to/from [ContentBlock].
///
/// This is the single place that knows the on-the-wire shape documented in
/// migration 0006 — every other layer only ever sees typed [ContentBlock]
/// subclasses.
class ContentBlockModel {
  static const _typeText = 'text';
  static const _typeImage = 'image';
  static const _typeVideo = 'video';
  static const _typeAudio = 'audio';

  static ContentBlock fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final publicationId = json['publication_id'] as String;
    final orderIndex = json['order_index'] as int;
    final data = json['data'] as Map<String, dynamic>;

    switch (json['type'] as String) {
      case _typeText:
        return TextContentBlock(
          id: id,
          publicationId: publicationId,
          orderIndex: orderIndex,
          text: data['text'] as String,
        );
      case _typeImage:
        // Check if this is a gallery (multiple images) or single image
        if (data['paths'] != null) {
          // Gallery format with multiple images
          final paths = List<String>.from(data['paths'] as List);
          final captions = data['captions'] != null 
              ? List<String?>.from(data['captions'] as List) 
              : List<String?>.filled(paths.length, null);
          // Ensure captions list matches paths length
          if (captions.length < paths.length) {
            captions.addAll(List<String?>.filled(paths.length - captions.length, null));
          } else if (captions.length > paths.length) {
            captions.removeRange(paths.length, captions.length);
          }
          return ImageContentBlock.gallery(
            id: id,
            publicationId: publicationId,
            orderIndex: orderIndex,
            imagePaths: paths,
            captions: captions,
          );
        } else {
          // Single image format (backward compatibility)
          return ImageContentBlock.single(
            id: id,
            publicationId: publicationId,
            orderIndex: orderIndex,
            imagePath: data['path'] as String,
            caption: data['caption'] as String?,
          );
        }
      case _typeVideo:
        return VideoContentBlock(
          id: id,
          publicationId: publicationId,
          orderIndex: orderIndex,
          url: data['url'] as String,
          provider: VideoProviderType.fromWireValue(data['provider'] as String),
          caption: data['caption'] as String?,
        );
      case _typeAudio:
        final source = AudioSourceType.fromWireValue(data['source'] as String);
        return AudioContentBlock(
          id: id,
          publicationId: publicationId,
          orderIndex: orderIndex,
          source: source,
          audioPath: source == AudioSourceType.upload ? data['path'] as String? : null,
          audioUrl: source == AudioSourceType.external ? data['url'] as String? : null,
          caption: data['caption'] as String?,
        );
      default:
        throw FormatException('Unknown content block type: ${json['type']}');
    }
  }

  /// Builds the row payload for insert/upsert. `id` is included so callers
  /// can upsert existing blocks (kept id) alongside new ones (fresh uuid).
  static Map<String, dynamic> toInsertJson(ContentBlock block, String publicationId) {
    return {
      'id': block.id,
      'publication_id': publicationId,
      'order_index': block.orderIndex,
      'type': _typeOf(block),
      'data': _dataOf(block),
    };
  }

  static String _typeOf(ContentBlock block) => switch (block) {
        TextContentBlock() => _typeText,
        ImageContentBlock() => _typeImage,
        VideoContentBlock() => _typeVideo,
        AudioContentBlock() => _typeAudio,
      };

  static Map<String, dynamic> _dataOf(ContentBlock block) => switch (block) {
        TextContentBlock(text: final text) => {'text': text},
        ImageContentBlock(imagePaths: final paths, captions: final captions) => {
            if (paths.length == 1) 'path': paths.first,
            if (paths.length == 1 && captions.first != null) 'caption': captions.first,
            if (paths.length > 1) 'paths': paths,
            if (paths.length > 1) 'captions': captions,
          },
        VideoContentBlock(url: final url, provider: final provider, caption: final caption) => {
            'url': url,
            'provider': provider.wireValue,
            'caption': caption,
          },

        AudioContentBlock(
          source: final source,
          audioPath: final path,
          audioUrl: final url,
          caption: final caption,
        ) =>
          {
            'source': source.wireValue,
            if (source == AudioSourceType.upload) 'path': path,
            if (source == AudioSourceType.external) 'url': url,
            'caption': caption,
          },
      };
}
