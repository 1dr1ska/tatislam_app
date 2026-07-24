/// Converts arbitrary text (including Cyrillic/Tatar) into a URL-safe slug.
///
/// Example: "Хутбалар һәм вәгазьләр" -> "hutbalar-h-m-v-gaz-l-r"
///
/// This is intentionally simple (transliteration table + ascii fallback)
/// rather than a full-blown i18n slug library, since slugs here are only
/// used as stable, human-readable identifiers for sections — not for SEO.
String slugify(String input) {
  final transliterated = _transliterate(input.trim().toLowerCase());

  final slug = transliterated
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'[\s_-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  return slug.isEmpty ? 'section' : slug;
}

const Map<String, String> _cyrillicToLatin = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
  'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
  'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
  'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
  // Tatar-specific letters
  'ә': 'a', 'ө': 'o', 'ү': 'u', 'җ': 'j', 'ң': 'n', 'һ': 'h',
};

String _transliterate(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_cyrillicToLatin[char] ?? char);
  }
  return buffer.toString();
}
