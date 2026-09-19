import 'package:equatable/equatable.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';

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
  /// Ordered Storage paths (e.g. `blocks/<publicationId>/images/<id>.jpg`) —
  /// never public URLs. Resolved via [MediaStorageRepository.publicUrlFor].
  ///
  /// A block can hold one or many photos (a Telegram-style album); legacy rows
  /// that stored a single `path` in the DB are parsed into a one-element list.
  ///
  /// May be empty only while the block is being edited in the admin UI (a
  /// placeholder that is filtered out before saving).
  final List<String> imagePaths;

  const ImageContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    required this.imagePaths,
  });

  /// Backwards-compatible accessor: the first photo's path, or `''` when the
  /// block has no photos. Keeps single-photo call sites (admin editor, upload
  /// queue) working unchanged.
  String get imagePath => imagePaths.firstOrNull ?? '';

  /// Replaces the whole photo list. `imagePath` (a single path) is accepted
  /// for backwards compatibility with the admin editor; `imagePaths` takes
  /// precedence when both are provided.
  ImageContentBlock copyWith({
    List<String>? imagePaths,
    String? imagePath,
    int? orderIndex,
  }) =>
      ImageContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex ?? this.orderIndex,
        imagePaths: imagePaths ?? (imagePath != null ? [imagePath] : this.imagePaths),
      );

  @override
  List<Object?> get props => [...super.props, imagePaths];
}

class VideoContentBlock extends ContentBlock {
  /// Where the video lives: [VideoSourceType.external] (youtube/rutube/vk/direct
  /// — a plain URL) or [VideoSourceType.upload] (a file in Yandex Storage).
  final VideoSourceType source;

  /// Set when [source] is [VideoSourceType.external] — the embeddable URL.
  final String url;

  final VideoProviderType provider;

  /// Set when [source] is [VideoSourceType.upload] — a Storage path
  /// (e.g. `videos/<uuid>.mp4`), resolved via [MediaStorageRepository.publicUrlFor].
  final String? videoPath;

  /// Original file name of the uploaded video (e.g. `вагазь.mp4`).
  final String? videoName;

  final String? videoMime;

  /// Size in bytes (uploaded videos only).
  final int? videoSize;

  const VideoContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    this.source = VideoSourceType.external,
    required this.url,
    required this.provider,
    this.videoPath,
    this.videoName,
    this.videoMime,
    this.videoSize,
  });

  VideoContentBlock copyWith({
    VideoSourceType? source,
    String? url,
    VideoProviderType? provider,
    String? videoPath,
    String? videoName,
    String? videoMime,
    int? videoSize,
    int? orderIndex,
  }) => VideoContentBlock(
    id: id,
    publicationId: publicationId,
    orderIndex: orderIndex ?? this.orderIndex,
    source: source ?? this.source,
    url: url ?? this.url,
    provider: provider ?? this.provider,
    videoPath: videoPath ?? this.videoPath,
    videoName: videoName ?? this.videoName,
    videoMime: videoMime ?? this.videoMime,
    videoSize: videoSize ?? this.videoSize,
  );

  @override
  List<Object?> get props => [
    ...super.props,
    source,
    url,
    provider,
    videoPath,
    videoName,
    videoMime,
    videoSize,
  ];
}

class FileContentBlock extends ContentBlock {
  /// Storage path of the file (e.g. `files/<uuid>.pdf`), resolved via
  /// [MediaStorageRepository.publicUrlFor]. Never a public URL.
  final String path;

  /// Original file name shown to the user (e.g. `методичка.pdf`).
  final String name;

  final int? size;

  final String? mimeType;

  const FileContentBlock({
    required super.id,
    required super.publicationId,
    required super.orderIndex,
    this.path = '',
    this.name = '',
    this.size,
    this.mimeType,
  });

  FileContentBlock copyWith({
    String? path,
    String? name,
    int? size,
    String? mimeType,
    int? orderIndex,
  }) =>
      FileContentBlock(
        id: id,
        publicationId: publicationId,
        orderIndex: orderIndex ?? this.orderIndex,
        path: path ?? this.path,
        name: name ?? this.name,
        size: size ?? this.size,
        mimeType: mimeType ?? this.mimeType,
      );

  @override
  List<Object?> get props => [...super.props, path, name, size, mimeType];
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
