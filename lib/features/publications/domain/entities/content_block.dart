import 'package:equatable/equatable.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';

/// A single piece of a publication's body.
///
/// A publication is an ordered, unbounded list of these — any mix, any
/// order (see migration 0006). Being a sealed class gives exhaustive,
/// compile-time-checked `switch` handling wherever blocks are rendered or
/// edited, while the DB stays flexible via a single JSONB `data` column.
///
/// Adding a new block type later means: one new subclass here, one new
/// case in the (de)serializer, one new renderer widget — no changes to
/// existing blocks.
sealed class ContentBlock extends Equatable {
  final String id;
  final String publicationId;
  final int orderIndex;

  const ContentBlock({
    required this.id,
    required this.publicationId,
    required this.orderIndex,
  });

  @override
  List<Object?> get props => [id, publicationId, orderIndex];
}

class TextContentBlock extends ContentBlock {
  final String text;

  const TextContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required this.text,
  });

  TextContentBlock copyWith({String? text, int? orderIndex}) => TextContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex ?? this.orderIndex,
        text: text ?? this.text,
      );

  @override
  List<Object?> get props => [...super.props, text];
}

class ImageContentBlock extends ContentBlock {
  /// Storage paths (e.g. `blocks/<publicationId>/images/<id>.jpg`) — never
  /// public URLs. Resolved via [MediaStorageRepository.publicUrlFor].
  /// 
  /// For single images, this list contains one element. For galleries, it
  /// contains multiple elements.
  final List<String> imagePaths;
  final List<String?> captions;

  /// For backward compatibility with existing single-image blocks
  ImageContentBlock.single({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required String imagePath,
    String? caption,
  })  : imagePaths = [imagePath],
        captions = [caption];

  /// For new multi-image blocks
  /// 
  /// Note: This constructor cannot be const because it uses List parameters.
  /// For single images, use the const [single] constructor instead.
  // ignore: prefer_const_constructors_in_immutables
  ImageContentBlock.gallery({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required this.imagePaths,
    required this.captions,
  }) : assert(imagePaths.length == captions.length);

  /// For backward compatibility, get the first image path
  String get imagePath => imagePaths.first;

  /// For backward compatibility, get the first caption
  String? get caption => captions.first;

  ImageContentBlock copyWith({
    List<String>? imagePaths,
    List<String?>? captions,
    int? orderIndex,
  }) =>
      ImageContentBlock.gallery(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex ?? this.orderIndex,
        imagePaths: imagePaths ?? this.imagePaths,
        captions: captions ?? this.captions,
      );

  @override
  List<Object?> get props => [...super.props, imagePaths, captions];
}

class VideoContentBlock extends ContentBlock {
  /// Always an external URL — video is never uploaded to Storage.
  final String url;
  final VideoProviderType provider;
  final String? caption;

  const VideoContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required this.url,
    required this.provider,
    this.caption,
  });

  VideoContentBlock copyWith({
    String? url,
    VideoProviderType? provider,
    String? caption,
    int? orderIndex,
  }) =>
      VideoContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex ?? this.orderIndex,
        url: url ?? this.url,
        provider: provider ?? this.provider,
        caption: caption ?? this.caption,
      );

  @override
  List<Object?> get props => [...super.props, url, provider, caption];
}

class AudioContentBlock extends ContentBlock {
  final AudioSourceType source;

  /// Set when [source] is [AudioSourceType.upload] — a Storage path.
  final String? audioPath;

  /// Set when [source] is [AudioSourceType.external] — a plain URL.
  final String? audioUrl;
  final String? caption;

  const AudioContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required this.source,
    this.audioPath,
    this.audioUrl,
    this.caption,
  });

  AudioContentBlock copyWith({
    AudioSourceType? source,
    String? audioPath,
    String? audioUrl,
    String? caption,
    int? orderIndex,
  }) =>
      AudioContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex ?? this.orderIndex,
        source: source ?? this.source,
        audioPath: audioPath ?? this.audioPath,
        audioUrl: audioUrl ?? this.audioUrl,
        caption: caption ?? this.caption,
      );

  @override
  List<Object?> get props => [...super.props, source, audioPath, audioUrl, caption];
}
