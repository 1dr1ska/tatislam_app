import 'package:equatable/equatable.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';

/// Reactive UI state for one publication's offline copy.
class SavedPublicationState extends Equatable {
  final DownloadStatus status;

  /// Live download progress while [status] is [DownloadStatus.downloading].
  final DownloadProgress? progress;

  /// Total size of the completed copy (shown in the saved dialog).
  final int? totalBytes;

  const SavedPublicationState({
    this.status = DownloadStatus.notSaved,
    this.progress,
    this.totalBytes,
  });

  bool get isSaved => status == DownloadStatus.saved;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get hasFailed => status == DownloadStatus.failed;

  SavedPublicationState copyWith({
    DownloadStatus? status,
    DownloadProgress? progress,
    int? totalBytes,
  }) =>
      SavedPublicationState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        totalBytes: totalBytes ?? this.totalBytes,
      );

  @override
  List<Object?> get props => [status, progress, totalBytes];
}