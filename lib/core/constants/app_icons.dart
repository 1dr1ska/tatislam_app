/// Maps icon identifiers to local asset paths.
///
/// Usage: `Image.asset(AppIcons.path('book')!)`
class AppIcons {
  static const Map<String, String> paths = {
    'book': 'assets/images/icons/book.png',
    'audio': 'assets/images/icons/audio.png',
    'video': 'assets/images/icons/video.png',
    'pen': 'assets/images/icons/pen.png',
    'hands': 'assets/images/icons/hands.png',
  };

  /// Returns the asset path for [id], or null if unknown.
  static String? path(String? id) => id == null ? null : paths[id];

  /// Returns the asset path for [id], falling back to 'book' if null/unknown.
  static String pathOrDefault(String? id) => path(id) ?? paths['book']!;
}
