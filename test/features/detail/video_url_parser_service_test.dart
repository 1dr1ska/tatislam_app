import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/detail/domain/services/video_url_parser_service.dart';

void main() {
  const parser = VideoUrlParserService();
  const videoId = 'dQw4w9WgXcQ';

  group('VideoUrlParserService YouTube URLs', () {
    test('extracts IDs from standard and Shorts URLs', () {
      expect(
        parser.extractYouTubeId('https://www.youtube.com/watch?v=$videoId'),
        videoId,
      );
      expect(parser.extractYouTubeId('https://youtu.be/$videoId?t=3'), videoId);
      expect(
        parser.extractYouTubeId(
          'https://www.youtube.com/shorts/$videoId?feature=share',
        ),
        videoId,
      );
    });

    test('identifies only the Shorts route as portrait', () {
      expect(
        parser.isYouTubeShortsUrl('https://www.youtube.com/shorts/$videoId'),
        isTrue,
      );
      expect(
        parser.isYouTubeShortsUrl('https://www.youtube.com/watch?v=$videoId'),
        isFalse,
      );
    });

    test('rejects non-video YouTube URLs', () {
      expect(
        parser.extractYouTubeId('https://www.youtube.com/@tatislam'),
        isNull,
      );
    });
  });
}
