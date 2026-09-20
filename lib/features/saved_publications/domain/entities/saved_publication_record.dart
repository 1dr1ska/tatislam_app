import 'package:equatable/equatable.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';

/// Lightweight registry entry for a publication saved offline.
///
/// Kept in a Hive box so the home screen can render the saved-only list
/// without touching the network or reading back the (potentially large)
/// snapshot JSON.
class SavedPublicationRecord extends Equatable {
  final String publicationId;
  final DateTime savedAt;
  final DownloadStatus status;

  /// Cached total size in bytes (null until the download completes / sizes
  /// are known).
  final int? totalBytes;

  /// Publication metadata, used to render cards in the saved-only filter.
  final Publication publication;

  /// True when the publication contains at least one online-only video.
  final bool hasOnlineVideo;

  const SavedPublicationRecord({
    required this.publicationId,
    required this.savedAt,
    required this.status,
    this.totalBytes,
    required this.publication,
    required this.hasOnlineVideo,
  });

  SavedPublicationRecord copyWith({
    DateTime? savedAt,
    DownloadStatus? status,
    int? totalBytes,
    Publication? publication,
    bool? hasOnlineVideo,
  }) =>
      SavedPublicationRecord(
        publicationId: publicationId,
        savedAt: savedAt ?? this.savedAt,
        status: status ?? this.status,
        totalBytes: totalBytes ?? this.totalBytes,
        publication: publication ?? this.publication,
        hasOnlineVideo: hasOnlineVideo ?? this.hasOnlineVideo,
      );

  @override
  List<Object?> get props => [
    publicationId,
    savedAt,
    status,
    totalBytes,
    publication,
    hasOnlineVideo,
  ];
}