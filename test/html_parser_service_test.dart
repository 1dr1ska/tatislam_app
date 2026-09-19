import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/detail/domain/services/html_parser_service.dart';

void main() {
  final parser = HtmlParserService();

  group('parseToPlainText preserves existing tag rules', () {
    test('headings, paragraphs, lists, quotes', () {
      final html = '<h2>Башлык</h2><p>Абзац.</p><ul><li>Пункт</li></ul>';
      expect(parser.parseToPlainText(html), '\n\nБашлык\n\nАбзац.\n\n• Пункт\n\n\n');
    });

    test('br and formatting markers', () {
      final html = 'A<br>B <strong>bold</strong> <em>em</em>';
      expect(parser.parseToPlainText(html), 'A\nB *bold* _em_');
    });

    test('images are stripped', () {
      final html = 'Start <img src="x.jpg" alt="x"> end';
      expect(parser.parseToPlainText(html), 'Start  end');
    });

    test('unknown tags stay literal', () {
      final html = '<span>не знаю</span>';
      expect(parser.parseToPlainText(html), '<span>не знаю</span>');
    });
  });

  group('anchor links', () {
    test('extracts href together with link text', () {
      final segments = parser.parseToSegments(
        'До <a href="https://example.com">Пример</a> после.',
      );
      expect(segments.length, 3);
      expect(segments[0].text, 'До ');
      expect(segments[0].isLink, false);
      expect(segments[1].text, 'Пример');
      expect(segments[1].href, 'https://example.com');
      expect(segments[2].text, ' после.');
    });

    test('decodes entities in href and in link text', () {
      final segments = parser.parseToSegments(
        '<a href="https://x.test/?a=1&amp;b=2">A &amp; B</a>',
      );
      expect(segments.length, 1);
      expect(segments[0].href, 'https://x.test/?a=1&b=2');
      expect(segments[0].text, 'A & B');
    });

    test('supports single-quoted and unquoted hrefs', () {
      expect(
        parser.parseToSegments("<a href='https://a.test'>q</a>")[0].href,
        'https://a.test',
      );
      expect(
        parser.parseToSegments('<a href=https://a.test>u</a>')[0].href,
        'https://a.test',
      );
    });

    test('anchor without href becomes plain text', () {
      final segments = parser.parseToSegments('<a>обычный текст</a>');
      expect(segments.length, 1);
      expect(segments[0].text, 'обычный текст');
      expect(segments[0].isLink, false);
    });

    test('link text stays plain text when taken alone', () {
      expect(parser.parseToPlainText('<a href="https://x.test">Текст</a>'), 'Текст');
    });
  });

  group('bare URLs', () {
    test('splits https and www urls out of prose', () {
      final segments = parser.parseToSegments(
        'Смотри https://example.com. Или www.site.ru сейчас.',
      );
      expect(segments.map((s) => s.text), [
        'Смотри ',
        'https://example.com',
        '.',
        ' Или ',
        'www.site.ru',
        ' сейчас.',
      ]);
      expect(segments[1].href, 'https://example.com');
      expect(segments[4].href, 'https://www.site.ru');
    });

    test('www urls get an https scheme', () {
      expect(parser.parseToSegments('www.example.com')[0].href, 'https://www.example.com');
    });

    test('does not auto-link inside an anchor tag', () {
      final segments = parser.parseToSegments('<a href="https://a.test">https://a.test</a>');
      expect(segments.length, 1);
      expect(segments[0].href, 'https://a.test');
    });

    test('trailing punctuation is not part of the link', () {
      final segments = parser.parseToSegments('Сайт: https://a.test/path).');
      expect(segments[1].text, 'https://a.test/path');
      expect(segments[2].text, ').');
    });
  });

  group('entities', () {
    test('decodes named entities', () {
      expect(parser.parseToPlainText('&amp; &lt; &gt; &quot; &apos;'), '& < > " \'');
    });

    test('decodes numeric and hex entities', () {
      expect(parser.parseToPlainText('&#1042;&#1089;&#1077; &#x41;'), 'Все A');
    });

    test('unknown entities are left intact', () {
      expect(parser.parseToPlainText('&unknown;'), '&unknown;');
    });
  });
}