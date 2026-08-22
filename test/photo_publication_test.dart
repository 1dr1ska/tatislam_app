import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/core/storage/storage_paths.dart';
import 'package:tatislam_app/features/publications/data/models/content_block_model.dart';
import 'package:tatislam_app/features/publications/data/models/publication_model.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';

void main() {
  group('ContentBlockModel toInsertJson', () {
    test('preserves block id for upsert', () {
      const block = TextContentBlock(
        id: 'block-1',
        publicationId: 'pub-1',
        orderIndex: 0,
        text: 'hello',
      );

      final json = ContentBlockModel.toInsertJson(block, 'pub-1');
      expect(json['id'], 'block-1');
      expect(json['publication_id'], 'pub-1');
      expect(json['type'], 'text');
      expect(json['order_index'], 0);
      expect(json['data'], {'text': 'hello'});
    });
  });

  group('PublicationModel photo_path', () {
    test('fromJson parses photo_path', () {
      final model = PublicationModel.fromJson({
        'id': 'pub-1',
        'title': 'My photo',
        'published_at': '2024-01-01T10:00:00.000Z',
        'created_at': '2024-01-01T09:00:00.000Z',
        'updated_at': '2024-01-01T09:00:00.000Z',
        'type': 'photo',
        'status': 'published',
        'primary_section_id': 'sec-1',
        'photo_path': 'photos/pub-1/abc.jpg',
      });

      expect(model.photoPath, 'photos/pub-1/abc.jpg');
      expect(model.toEntity().type, 'photo');
      expect(model.toEntity().photoPath, 'photos/pub-1/abc.jpg');
    });

    test('fromJson handles missing photo_path as null', () {
      final model = PublicationModel.fromJson({
        'id': 'pub-1',
        'title': 'Article',
        'published_at': '2024-01-01T10:00:00.000Z',
        'created_at': '2024-01-01T09:00:00.000Z',
        'updated_at': '2024-01-01T09:00:00.000Z',
        'type': 'article',
        'primary_section_id': 'sec-1',
      });

      expect(model.photoPath, isNull);
      expect(model.toEntity().photoPath, isNull);
    });

    test('toInsertJson includes photo_path when set', () {
      final model = PublicationModel(
        id: '',
        title: 'Photo',
        publishedAt: DateTime.utc(2024, 1, 1),
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
        type: 'photo',
        primarySectionId: 'sec-1',
        photoPath: 'photos/pub-1/abc.jpg',
      );

      final json = model.toInsertJson();
      expect(json['photo_path'], 'photos/pub-1/abc.jpg');
    });

    test('toInsertJson omits photo_path when null', () {
      final model = PublicationModel(
        id: '',
        title: 'Article',
        publishedAt: DateTime.utc(2024, 1, 1),
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
        type: 'article',
        primarySectionId: 'sec-1',
      );

      final json = model.toInsertJson();
      expect(json.containsKey('photo_path'), isFalse);
    });
  });

  group('PublicationModel has_additional_sections', () {
    test('parses flag and serializes it', () {
      final model = PublicationModel.fromJson({
        'id': 'pub-1',
        'title': 'P',
        'published_at': '2024-01-01T10:00:00.000Z',
        'created_at': '2024-01-01T09:00:00.000Z',
        'updated_at': '2024-01-01T09:00:00.000Z',
        'type': 'article',
        'primary_section_id': 'sec-1',
        'has_additional_sections': true,
      });

      expect(model.hasAdditionalSections, isTrue);
      expect(model.toEntity().hasAdditionalSections, isTrue);
      expect(model.toInsertJson()['has_additional_sections'], isTrue);
    });

    test('defaults to false and toggles via copyWith', () {
      final model = PublicationModel.fromJson({
        'id': 'pub-1',
        'title': 'P',
        'published_at': '2024-01-01T10:00:00.000Z',
        'created_at': '2024-01-01T09:00:00.000Z',
        'updated_at': '2024-01-01T09:00:00.000Z',
        'type': 'article',
        'primary_section_id': 'sec-1',
      });

      expect(model.hasAdditionalSections, isFalse);

      final copy = model.toEntity().copyWith(hasAdditionalSections: true);
      expect(copy.hasAdditionalSections, isTrue);
      expect(copy.props, contains(true));
    });
  });

  group('Publication entity photo_path', () {
    test('copyWith sets and props include photoPath', () {
      final now = DateTime.now();
      final base = Publication(
        id: 'p1',
        title: 't',
        publishedAt: now,
        createdAt: now,
        updatedAt: now,
        type: 'photo',
        primarySectionId: 'sec-1',
      );
      final withPhoto = base.copyWith(photoPath: 'photos/p1/a.jpg');

      expect(withPhoto.photoPath, 'photos/p1/a.jpg');
      expect(withPhoto.props, contains('photos/p1/a.jpg'));
      expect(base.photoPath, isNull);
    });
  });

  group('StoragePaths.photo', () {
    test('builds photo path under photos folder', () {
      final path = StoragePaths.photo('pub-1', 'jpg', photoId: 'abc');
      expect(path, 'photos/pub-1/abc.jpg');
    });

    test('normalizes extension', () {
      final path = StoragePaths.photo('pub-1', '.JPEG', photoId: 'abc');
      expect(path, 'photos/pub-1/abc.jpeg');
    });
  });
}