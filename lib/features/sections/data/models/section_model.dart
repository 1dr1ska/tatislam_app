import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Maps a `sections` table row to/from [Section].
class SectionModel {
  final String id;
  final String name;
  final String slug;
  final bool isVisible;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SectionModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.isVisible,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    return SectionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      isVisible: json['is_visible'] as bool,
      sortOrder: json['sort_order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'slug': slug,
        'is_visible': isVisible,
        'sort_order': sortOrder,
      };

  Section toEntity() => Section(
        id: id,
        name: name,
        slug: slug,
        isVisible: isVisible,
        sortOrder: sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
