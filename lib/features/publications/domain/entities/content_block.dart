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

  TextContentBlock copyWith({String? text, int? orderIndex}) =>
      TextContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex ?? this.orderIndex,
        text: text ?? this.text,
      );

  @override
  List<Object?> get props => [...super.props, text];
}

class ImageContentBlock extends ContentBlock {
  /// Storage path (e.g. `blocks/<publicationId>/images/<id>.jpg`) — never
  /// a public URL. Resolved via [MediaStorageRepository.publicUrlFor].
  final String imagePath;

  const ImageContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required this.imagePath,
  });

  ImageContentBlock copyWith({String? imagePath, int? orderIndex}) =>
      ImageContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex ?? this.orderIndex,
        imagePath: imagePath ?? this.imagePath,
      );

  @override
  List<Object?> get props => [...super.props, imagePath];
}

class VideoContentBlock extends ContentBlock {
  /// Always an external URL — video is never uploaded to Storage.
  final String url;
  final VideoProviderType provider;

  const VideoContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required this.url,
    required this.provider,
  });

  VideoContentBlock copyWith({
    String? url,
    VideoProviderType? provider,
    int? orderIndex,
  }) => VideoContentBlock(
    id: id,
    publicationId: publicationId,
    orderIndex: orderIndex ?? this.orderIndex,
    url: url ?? this.url,
    provider: provider ?? this.provider,
  );

  @override
  List<Object?> get props => [...super.props, url, provider];
}

class AudioContentBlock extends ContentBlock {
  final AudioSourceType source;

  /// Set when [source] is [AudioSourceType.upload] — a Storage path.
  final String? audioPath;

  /// Set when [source] is [AudioSourceType.external] — a plain URL.
  final String? audioUrl;

  const AudioContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required this.source,
    this.audioPath,
    this.audioUrl,
  });

  AudioContentBlock copyWith({
    AudioSourceType? source,
    String? audioPath,
    String? audioUrl,
    int? orderIndex,
  }) => AudioContentBlock(
    id: id,
    publicationId: publicationId,
    orderIndex: orderIndex ?? this.orderIndex,
    source: source ?? this.source,
    audioPath: audioPath ?? this.audioPath,
    audioUrl: audioUrl ?? this.audioUrl,
  );

  @override
  List<Object?> get props => [...super.props, source, audioPath, audioUrl];
}
