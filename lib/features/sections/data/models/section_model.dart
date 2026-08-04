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
  final String? backgroundImage;

  const SectionModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.isVisible,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.backgroundImage,
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
      backgroundImage: json['background_image'] as String?,
    );
  }

  /// Full serialization for local caching (includes all fields).
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'is_visible': isVisible,
    'sort_order': sortOrder,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (backgroundImage != null) 'background_image': backgroundImage,
  };

  /// Minimal JSON for insert (no id, no timestamps — server fills them).
  Map<String, dynamic> toInsertJson() => {
    'name': name,
    'slug': slug,
    'is_visible': isVisible,
    'sort_order': sortOrder,
    if (backgroundImage != null) 'background_image': backgroundImage,
  };

  Section toEntity() => Section(
    id: id,
    name: name,
    slug: slug,
    isVisible: isVisible,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    backgroundImage: backgroundImage,
  );
}
