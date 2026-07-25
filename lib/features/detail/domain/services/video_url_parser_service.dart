/// Pure domain service — extracts video platform IDs from URLs.
///
/// No Flutter dependencies. Can be unit-tested without any framework.
class VideoUrlParserService {
  const VideoUrlParserService();

  /// Extracts YouTube video ID from various YouTube URL formats.
  ///
  /// Supports:
  /// - `https://www.youtube.com/watch?v=ID`
  /// - `https://youtu.be/ID`
  /// - `https://youtube.com/embed/ID`
  /// - `https://youtube.com/v/ID`
  String? extractYouTubeId(String url) {
    final regex = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Extracts Rutube video ID from various Rutube URL formats.
  ///
  /// Supports:
  /// - `https://rutube.ru/video/32charHexId/`
  /// - `https://rutube.ru/video/private/32charHexId/?p=...`
  String? extractRutubeId(String url) {
    final publicRegex = RegExp(r'rutube\.ru\/video\/([a-f0-9]{32})');
    final privateRegex = RegExp(r'rutube\.ru\/video\/private\/([a-f0-9]{32})');

    final publicMatch = publicRegex.firstMatch(url);
    if (publicMatch != null) {
      return publicMatch.group(1);
    }

    final privateMatch = privateRegex.firstMatch(url);
    if (privateMatch != null) {
      return privateMatch.group(1);
    }

    return null;
  }

  /// Checks whether [url] has a valid http/https scheme.
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
}