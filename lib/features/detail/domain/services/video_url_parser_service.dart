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
  /// - `https://youtube.com/shorts/ID`
  String? extractYouTubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    final isYoutube = host == 'youtube.com' || host.endsWith('.youtube.com');
    final isShortUrl = host == 'youtu.be' || host.endsWith('.youtu.be');
    if (!isYoutube && !isShortUrl) return null;

    String? id;
    if (isShortUrl) {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (uri.path == '/watch') {
      id = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        const {
          'embed',
          'v',
          'shorts',
          'live',
        }.contains(uri.pathSegments.first)) {
      id = uri.pathSegments[1];
    }

    // YouTube IDs are currently 11 characters. Keeping this validation avoids
    // turning unrelated YouTube URLs (channels, playlists, etc.) into embeds.
    return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)
        ? id
        : null;
  }

  /// Whether the URL uses YouTube's Shorts route. Shorts are presented in a
  /// portrait player by YouTube, so the embedding surface must not force 16:9.
  bool isYouTubeShortsUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final isYoutube = host == 'youtube.com' || host.endsWith('.youtube.com');
    return isYoutube &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'shorts' &&
        extractYouTubeId(url) != null;
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
