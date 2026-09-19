/// Pure domain service — parses simple HTML tags into plain text.
///
/// No Flutter dependencies, no UI. Can be unit-tested without any framework.
class HtmlParserService {
  const HtmlParserService();

  /// Strips simple HTML tags from [html] and replaces them with
  /// plain-text equivalents (newlines, markdown-like markers).
  String parseToPlainText(String html) {
    return parseToSegments(html).map((segment) => segment.text).join();
  }

  /// Parses [html] into a list of text fragments.
  ///
  /// Applies the same plain-text transformations as [parseToPlainText] and
  /// additionally marks fragments that are hyperlinks:
  ///
  ///  * `<a href="…">…</a>` tags keep the `href` attribute;
  ///  * bare URLs (`https://…`, `http://…`, `www.…`) that appear outside of
  ///    any tag are auto-linked. `www.`-prefixed URLs get an `https://` scheme
  ///    so they can be opened directly.
  ///
  /// HTML entities (`&amp;`, `&#39;`, `&nbsp;`, …) are decoded both in the
  /// visible text and in hrefs.
  List<TextContentSegment> parseToSegments(String html) {
    final segments = <TextContentSegment>[];
    final normalBuffer = StringBuffer();
    final linkBuffer = StringBuffer();
    final linkHrefs = <String>[];

    void appendToCurrent(String piece) {
      (linkHrefs.isEmpty ? normalBuffer : linkBuffer).write(piece);
    }

    void flushNormalText() {
      final text = _decodeEntities(normalBuffer.toString());
      normalBuffer.clear();
      _splitBareLinks(text, segments);
    }

    void flushLinkText() {
      if (linkHrefs.isEmpty) {
        return;
      }
      final text = _decodeEntities(linkBuffer.toString());
      linkBuffer.clear();
      final href = linkHrefs.removeLast();
      if (text.isEmpty || href.isEmpty) {
        // An empty anchor — keep the text (if any) as plain text.
        _splitBareLinks(text, segments);
        return;
      }
      segments.add(TextContentSegment(text: text, href: href));
    }

    var index = 0;
    while (index < html.length) {
      final open = html.indexOf('<', index);
      if (open == -1) {
        appendToCurrent(html.substring(index));
        break;
      }
      if (open > index) {
        appendToCurrent(html.substring(index, open));
      }

      // HTML comments are removed whole so their `>` doesn't confuse parsing.
      if (html.startsWith('<!--', open)) {
        final commentEnd = html.indexOf('-->', open + 4);
        if (commentEnd == -1) {
          break;
        }
        index = commentEnd + 3;
        continue;
      }

      final close = html.indexOf('>', open + 1);
      if (close == -1) {
        // Unterminated tag — treat the remainder as plain text.
        appendToCurrent(html.substring(open));
        break;
      }

      final rawTag = html.substring(open + 1, close);
      index = close + 1;

      // Other declarations (e.g. doctype, CDATA) — skip without emitting.
      if (rawTag.startsWith('!')) {
        continue;
      }

      final isClosing = rawTag.startsWith('/');
      final body = isClosing ? rawTag.substring(1).trimLeft() : rawTag.trimLeft();
      final name = _tagName(body);

      if (name == 'a') {
        if (isClosing) {
          flushLinkText();
        } else {
          final href = _extractHref(body);
          if (href != null && href.trim().isNotEmpty) {
            flushNormalText();
            linkHrefs.add(_decodeEntities(href).trim());
          }
          // `<a>` without an href is skipped entirely.
        }
        continue;
      }

      final marker = isClosing ? _closingMarkers[name] : _openingMarkers[name];
      if (marker == null) {
        // Unknown tag — preserve it verbatim, mirroring the original
        // tag-stripping behaviour.
        appendToCurrent('<$rawTag>');
        continue;
      }
      appendToCurrent(marker);
    }

    flushLinkText();
    flushNormalText();
    return segments;
  }
}

/// A single fragment of parsed text content.
///
/// [href] is set only for fragments that are hyperlinks (an `<a href="…">` tag
/// or a bare URL detected in the text).
class TextContentSegment {
  final String text;
  final String? href;

  const TextContentSegment({required this.text, this.href});

  bool get isLink => href != null;
}
const Map<String, String> _openingMarkers = {
  'h1': '\n\n',
  'h2': '\n\n',
  'h3': '\n\n',
  'p': '',
  'br': '\n',
  'ul': '',
  'ol': '',
  'li': '• ',
  'blockquote': '“',
  'strong': '*',
  'em': '_',
  'img': '',
};

const Map<String, String> _closingMarkers = {
  'h1': '\n\n',
  'h2': '\n\n',
  'h3': '\n\n',
  'p': '\n\n',
  'ul': '\n\n',
  'ol': '\n\n',
  'li': '\n',
  'blockquote': '”',
  'strong': '*',
  'em': '_',
};

final RegExp _hrefPattern = RegExp(
  r"""\bhref\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'>]+))""",
  caseSensitive: false,
);

/// Returns the lower-cased name of the tag represented by [body].
String _tagName(String body) {
  var end = 0;
  while (end < body.length && !' \t\r\n/>'.contains(body[end])) {
    end += 1;
  }
  return body.substring(0, end).toLowerCase();
}

/// Extracts the `href` attribute value from an `<a …>` tag body, or null when
/// the tag has no href.
String? _extractHref(String body) {
  final match = _hrefPattern.firstMatch(body);
  if (match == null) {
    return null;
  }
  final doubleQuoted = match.group(2);
  if (doubleQuoted != null) {
    return doubleQuoted;
  }
  final singleQuoted = match.group(3);
  if (singleQuoted != null) {
    return singleQuoted;
  }
  return match.group(4);
}

final RegExp _entityPattern = RegExp(r'&(#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z]{2,8});');

/// Decodes common HTML entities in [input]. Unknown entities are kept as-is.
String _decodeEntities(String input) {
  if (!input.contains('&')) {
    return input;
  }
  return input.replaceAllMapped(_entityPattern, (match) {
    final body = match.group(1)!;
    if (body.startsWith('#')) {
      final isHex = body[1] == 'x' || body[1] == 'X';
      final digits = isHex ? body.substring(2) : body.substring(1);
      final codePoint = int.parse(digits, radix: isHex ? 16 : 10);
      try {
        return String.fromCharCode(codePoint);
      } catch (_) {
        return match.group(0)!;
      }
    }
    return switch (body) {
      'amp' => '&',
      'lt' => '<',
      'gt' => '>',
      'quot' => '"',
      'apos' => "'",
      'nbsp' => '\u00A0',
      _ => match.group(0)!,
    };
  });
}

final RegExp _bareUrlPattern = RegExp(
  r'''https?://[^\s<>"']+|www\.[^\s<>"']+''',
);

/// Punctuation characters that often get glued to a URL in prose and should
/// not be part of the link.
const String _urlTrailingPunctuation = '.,;:!?…"”»)]}';

/// Splits [text] into plain fragments and bare-URL fragments, appending them
/// to [segments].
void _splitBareLinks(String text, List<TextContentSegment> segments) {
  var cursor = 0;
  for (final match in _bareUrlPattern.allMatches(text)) {
    final rawUrl = match.group(0)!;
    var end = rawUrl.length;
    while (end > 0 && _urlTrailingPunctuation.contains(rawUrl[end - 1])) {
      end -= 1;
    }
    if (match.start > cursor) {
      segments.add(TextContentSegment(text: text.substring(cursor, match.start)));
    }
    if (end > 0) {
      final url = rawUrl.substring(0, end);
      segments.add(
        TextContentSegment(
          text: url,
          href: url.startsWith('www.') ? 'https://$url' : url,
        ),
      );
    }
    if (end < rawUrl.length) {
      // Punctuation that was glued to the URL stays as plain text.
      segments.add(TextContentSegment(text: rawUrl.substring(end)));
    }
    cursor = match.start + rawUrl.length;
  }
  if (cursor < text.length) {
    segments.add(TextContentSegment(text: text.substring(cursor)));
  }
}
