import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_provider_type.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/offline_plan.dart';

VideoContentBlock _video({
  required VideoSourceType source,
  VideoProviderType provider = VideoProviderType.youtube,
  String url = '',
  String? videoPath,
  String? videoName,
  int? videoSize,
}) =>
    VideoContentBlock(
      id: 'v1',
      publicationId: 'p1',
      orderIndex: 0,
      source: source,
      url: url,
      provider: provider,
      videoPath: videoPath,
      videoName: videoName,
      videoSize: videoSize,
    );

void main() {
  group('buildOfflinePlan — video handling', () {
    test('uploaded video becomes a downloadable video resource', () {
      final plan = buildOfflinePlan([
        _video(
          source: VideoSourceType.upload,
          videoPath: 'videos/abc.mp4',
          videoName: 'вагазь.mp4',
          videoSize: 1024 * 1024,
        ),
      ]);

      expect(plan.hasVideo, isTrue);
      expect(plan.hasOnlineVideo, isFalse);
      expect(plan.resources, hasLength(1));

      final r = plan.resources.single;
      expect(r.kind, 'video');
      expect(r.blockId, 'v1');
      expect(r.storagePath, 'videos/abc.mp4');
      expect(r.knownBytes, 1024 * 1024);
      expect(r.name, 'вагазь.mp4');
      expect(r.extension, 'mp4');
    });

    test('uploaded video without a path stays online-only', () {
      final plan = buildOfflinePlan([
        _video(source: VideoSourceType.upload),
      ]);

      expect(plan.hasVideo, isFalse);
      expect(plan.hasOnlineVideo, isTrue);
      expect(plan.resources, isEmpty);
    });

    test('external videos are never downloaded and flagged online-only', () {
      final plan = buildOfflinePlan([
        _video(
          source: VideoSourceType.external,
          provider: VideoProviderType.youtube,
          url: 'https://youtube.com/watch?v=abc',
        ),
        _video(
          source: VideoSourceType.external,
          provider: VideoProviderType.rutube,
          url: 'https://rutube.ru/video/xyz',
        ),
      ]);

      expect(plan.hasVideo, isFalse);
      expect(plan.hasOnlineVideo, isTrue);
      expect(plan.resources, isEmpty);
    });

    test('mixed publication downloads the uploaded video only', () {
      final plan = buildOfflinePlan([
        _video(
          source: VideoSourceType.upload,
          videoPath: 'videos/sermon.mp4',
        ),
        _video(
          source: VideoSourceType.external,
          provider: VideoProviderType.youtube,
          url: 'https://youtube.com/watch?v=abc',
        ),
        TextContentBlock(
          id: 't1',
          publicationId: 'p1',
          orderIndex: 2,
          text: 'text',
        ),
      ]);

      expect(plan.hasVideo, isTrue);
      expect(plan.hasOnlineVideo, isTrue);
      expect(plan.resources.single.kind, 'video');
      expect(plan.resources.single.storagePath, 'videos/sermon.mp4');
    });
  });
}