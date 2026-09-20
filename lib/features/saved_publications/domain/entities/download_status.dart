/// Lifecycle of a single publication's offline copy.
enum DownloadStatus {
  /// Nothing has been saved for this publication.
  notSaved,

  /// A download for this publication is currently in flight.
  downloading,

  /// All supported content is present on-device and verified.
  saved,

  /// A previous download attempt failed (partial data was cleaned up).
  failed,
}

/// Aggregated download progress across all resources of one publication.
///
/// [totalBytes] may be null/zero when the server does not report a
/// `Content-Length` for some resource — the caller should then treat the
/// overall progress as indeterminate ([isIndeterminate]).
class DownloadProgress {
  final int downloadedBytes;
  final int? totalBytes;

  const DownloadProgress({
    this.downloadedBytes = 0,
    this.totalBytes,
  });

  bool get isIndeterminate =>
      totalBytes == null || totalBytes! <= 0;

  /// Normalised 0.0 → 1.0 progress, or 0.0 when indeterminate.
  double get fraction {
    if (isIndeterminate || totalBytes! <= 0) return 0.0;
    return (downloadedBytes / totalBytes!).clamp(0.0, 1.0);
  }

  /// Percent as a whole number (0-100). 0 when indeterminate.
  int get percent => (fraction * 100).round().clamp(0, 100);
}

/// Cooperative cancellation signal used by long-running save operations.
///
/// Kept Dio/io-free so the domain layer stays platform-agnostic. The data
/// layer polls `isCancelled` between resource downloads.
class SavingCancelSignal {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}