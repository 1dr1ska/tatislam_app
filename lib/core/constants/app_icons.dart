/// Maps icon identifiers to local asset paths.
///
/// Usage: `Image.asset(AppIcons.path('book')!)`
class AppIcons {
  static const Map<String, String> paths = {
    'book': 'assets/images/icons/книга.png',
    'audio': 'assets/images/icons/аудио.png',
    'video': 'assets/images/icons/ютуб.png',
    'pen': 'assets/images/icons/перо.png',
    'hands': 'assets/images/icons/руки.png',
  };

  /// Returns the asset path for [id], or null if unknown.
  static String? path(String? id) => id == null ? null : paths[id];

  /// Returns the asset path for [id], falling back to 'book' if null/unknown.
  static String pathOrDefault(String? id) => path(id) ?? paths['book']!;
}