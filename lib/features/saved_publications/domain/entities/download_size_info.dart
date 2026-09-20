/// Estimated size + content breakdown shown in the "save" confirmation
/// dialog before a download starts.
class DownloadSizeInfo {
  /// Total bytes of the content that will be downloaded.
  ///
  /// `null` when at least one resource did not report a length — the UI must
  /// then say the size could not be determined instead of showing a wrong
  /// figure.
  final int? totalBytes;

  /// True when a resource had no known size, making [totalBytes] unreliable.
  final bool hasUnknownSize;

  final bool hasOnlineVideo;
  final bool hasImage;
  final bool hasAudio;
  final bool hasFile;
  final bool hasVideo;

  const DownloadSizeInfo({
    this.totalBytes,
    required this.hasUnknownSize,
    required this.hasOnlineVideo,
    required this.hasImage,
    required this.hasAudio,
    required this.hasFile,
    required this.hasVideo,
  });
}