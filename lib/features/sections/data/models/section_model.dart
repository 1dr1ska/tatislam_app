import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Maps a `sections` table row to/from [Section].
class SectionModel {
  final String id;
  final String name;
  final String? nameRu;
  final String slug;
  final bool isVisible;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? backgroundImage;
  final bool isDefaultForPhoto;

  const SectionModel({
    required this.id,
    required this.name,
    this.nameRu,
    required this.slug,
    required this.isVisible,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.backgroundImage,
    this.isDefaultForPhoto = false,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    return SectionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      nameRu: json['name_ru'] as String?,
      slug: json['slug'] as String,
      isVisible: json['is_visible'] as bool,
      sortOrder: json['sort_order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      backgroundImage: json['background_image'] as String?,
      isDefaultForPhoto: json['is_default_for_photo'] as bool? ?? false,
    );
  }

  /// Full serialization for local caching (includes all fields).
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'name_ru': ?nameRu,
    'slug': slug,
    'is_visible': isVisible,
    'sort_order': sortOrder,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (backgroundImage != null) 'background_image': backgroundImage,
    'is_default_for_photo': isDefaultForPhoto,
  };

  /// Minimal JSON for insert (no id, no timestamps — server fills them).
  Map<String, dynamic> toInsertJson() => {
    'name': name,
    'name_ru': ?nameRu,
    'slug': slug,
    'is_visible': isVisible,
    'sort_order': sortOrder,
    if (backgroundImage != null) 'background_image': backgroundImage,
    'is_default_for_photo': isDefaultForPhoto,
  };

  Section toEntity() => Section(
    id: id,
    name: name,
    nameRu: nameRu,
    slug: slug,
    isVisible: isVisible,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    backgroundImage: backgroundImage,
    isDefaultForPhoto: isDefaultForPhoto,
  );
}
