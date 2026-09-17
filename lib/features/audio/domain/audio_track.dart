import 'package:audio_service/audio_service.dart';
import 'package:equatable/equatable.dart';
import 'package:tatislam_app/features/audio/data/audio_artwork_file.dart';
import 'package:tatislam_app/features/publications/domain/entities/audio_source_type.dart';

/// Descriptor of a single audio track loaded into the shared audio player.
///
/// This is the app-level representation of «what is playing right now»: the detail
/// audio block, the Mini Player, the full player screen and the system media
/// notification all read from it. Playback internals intentionally live only in
/// the single shared `AudioPlayer` (see `AudioPlayerService`).
class AudioTrack extends Equatable {
  /// Unique content-block id. Used as the `MediaItem.id` and as a stable
  /// per-track key for the saved playback position.
  final String id;

  /// Publication containing this audio block.
  final String publicationId;

  /// Absolute stream URL of the audio.
  final String url;

  /// Human-readable title shown in the UI and the media notification.
  final String title;

  /// Optional secondary line (e.g. publication date). Shown when available.
  final String? subtitle;

  /// Where the file lives — controls how the URL/file name is derived.
  final AudioSourceType source;

  /// Storage path for `upload` sources (used to derive a file name for shares).
  final String? audioPath;

  const AudioTrack({
    required this.id,
    required this.publicationId,
    required this.url,
    required this.title,
    this.subtitle,
    this.source = AudioSourceType.external,
    this.audioPath,
  });

  /// Stable Hive key under which the per-track playback position is persisted.
  String get positionKey => 'audio_position_${publicationId}_$id';

  /// Metadata handed to the system media notification / lock screen.
  MediaItem toMediaItem() => MediaItem(
    id: id,
    title: title,
    album: subtitle,
    // Notification «фон»: the mountains background prepared once at startup.
    artUri: AudioArtworkFile.uri,
  );

  /// A safe human-visible file name for downloads/shares, when a better one
  /// cannot be derived from the upload path.
  String get fileName {
    final segment = url
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList()
        .lastOrNull;
    if (segment != null && segment.contains('.')) return segment;
    return 'audio.mp3';
  }

  AudioTrack copyWith({
    String? id,
    String? publicationId,
    String? url,
    String? title,
    String? subtitle,
    AudioSourceType? source,
    String? audioPath,
    bool clearSubtitle = false,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      publicationId: publicationId ?? this.publicationId,
      url: url ?? this.url,
      title: title ?? this.title,
      subtitle: clearSubtitle ? null : (subtitle ?? this.subtitle),
      source: source ?? this.source,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  @override
  List<Object?> get props => [
    id,
    publicationId,
    url,
    title,
    subtitle,
    source,
    audioPath,
  ];

  @override
  String toString() => 'AudioTrack(id: $id, title: $title, url: $url)';
}
