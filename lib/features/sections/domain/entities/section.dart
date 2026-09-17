import 'package:equatable/equatable.dart';

/// An admin-managed content category (e.g. "Мәкаләләр", "Хутбалар").
///
/// A publication may belong to any number of sections — see
/// `publication_sections` in SUPABASE_SETUP.md.
class Section extends Equatable {
  final String id;
  final String name;
  final String slug;
  final bool isVisible;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? backgroundImage;

  /// When true, new photo publications get this section preselected as their
  /// primary section. Only one section can be the default at a time.
  final bool isDefaultForPhoto;

  const Section({
    required this.id,
    required this.name,
    required this.slug,
    required this.isVisible,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.backgroundImage,
    this.isDefaultForPhoto = false,
  });

  Section copyWith({
    String? name,
    String? slug,
    bool? isVisible,
    int? sortOrder,
    String? backgroundImage,
    bool? isDefaultForPhoto,
  }) {
    return Section(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      isDefaultForPhoto: isDefaultForPhoto ?? this.isDefaultForPhoto,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    isVisible,
    sortOrder,
    createdAt,
    updatedAt,
    backgroundImage,
    isDefaultForPhoto,
  ];
}
