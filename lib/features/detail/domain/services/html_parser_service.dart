/// Pure domain service — parses simple HTML tags into plain text.
///
/// No Flutter dependencies, no UI. Can be unit-tested without any framework.
class HtmlParserService {
  const HtmlParserService();

  /// Strips simple HTML tags from [html] and replaces them with
  /// plain-text equivalents (newlines, markdown-like markers).
  String parseToPlainText(String html) {
    return html
        .replaceAll('<h1>', '\n\n')
        .replaceAll('</h1>', '\n\n')
        .replaceAll('<h2>', '\n\n')
        .replaceAll('</h2>', '\n\n')
        .replaceAll('<h3>', '\n\n')
        .replaceAll('</h3>', '\n\n')
        .replaceAll('<p>', '')
        .replaceAll('</p>', '\n\n')
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<ul>', '')
        .replaceAll('</ul>', '\n\n')
        .replaceAll('<ol>', '')
        .replaceAll('</ol>', '\n\n')
        .replaceAll('<li>', '• ')
        .replaceAll('</li>', '\n')
        .replaceAll('<blockquote>', '“')
        .replaceAll('</blockquote>', '”')
        .replaceAll('<strong>', '*')
        .replaceAll('</strong>', '*')
        .replaceAll('<em>', '_')
        .replaceAll('</em>', '_')
        .replaceAll('<img[^>]*>', '');
  }
}