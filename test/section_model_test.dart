import 'package:flutter_test/flutter_test.dart';
import 'package:tatislam_app/features/sections/data/models/section_model.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

void main() {
  Map<String, dynamic> sectionJson({bool? isDefaultForPhoto}) => {
    'id': 'sec-1',
    'name': 'Рәсемнәр',
    'slug': 'photos',
    'is_visible': true,
    'sort_order': 0,
    'created_at': '2024-01-01T09:00:00.000Z',
    'updated_at': '2024-01-01T09:00:00.000Z',
    'is_default_for_photo': ?isDefaultForPhoto,
  };

  group('SectionModel is_default_for_photo', () {
    test('parses is_default_for_photo=true and carries it to the entity', () {
      final model = SectionModel.fromJson(
        sectionJson(isDefaultForPhoto: true),
      );

      expect(model.isDefaultForPhoto, isTrue);
      expect(model.toEntity().isDefaultForPhoto, isTrue);
      expect(model.toJson()['is_default_for_photo'], isTrue);
      expect(model.toInsertJson()['is_default_for_photo'], isTrue);
    });

    test('defaults to false when column is missing', () {
      final model = SectionModel.fromJson(sectionJson());

      expect(model.isDefaultForPhoto, isFalse);
      expect(model.toEntity().isDefaultForPhoto, isFalse);
    });
  });

  group('Section entity is_default_for_photo', () {
    test('copyWith sets the flag and props include it', () {
      final base = Section(
        id: 'sec-1',
        name: 'Рәсемнәр',
        slug: 'photos',
        isVisible: true,
        sortOrder: 0,
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );

      expect(base.isDefaultForPhoto, isFalse);

      final withDefault = base.copyWith(isDefaultForPhoto: true);
      expect(withDefault.isDefaultForPhoto, isTrue);
      expect(withDefault.props, contains(true));

      // copyWith must not leak the flag into the original.
      expect(base.isDefaultForPhoto, isFalse);
    });
  });
}