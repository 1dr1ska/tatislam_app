import 'package:equatable/equatable.dart';
import 'package:tatislam_app/core/providers/locale_provider.dart';

/// An admin-managed content category (e.g. "Мәкаләләр", "Хутбалар").
///
/// A publication may belong to any number of sections — see
/// `publication_sections` in SUPABASE_SETUP.md.
class Section extends Equatable {
  final String id;
  final String name;
  /// Optional Russian name. When present and the interface language is Russian,
  /// [localizedName] returns it; otherwise the (Tatar) [name] is used.
  final String? nameRu;
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
    this.nameRu,
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
    String? nameRu,
    String? slug,
    bool? isVisible,
    int? sortOrder,
    String? backgroundImage,
    bool? isDefaultForPhoto,
  }) {
    return Section(
      id: id,
      name: name ?? this.name,
      nameRu: nameRu ?? this.nameRu,
      slug: slug ?? this.slug,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      isDefaultForPhoto: isDefaultForPhoto ?? this.isDefaultForPhoto,
    );
  }

  /// Returns the name to display for the given [locale]. When the interface is
  /// Russian and a Russian name was provided, that is used; otherwise the
  /// primary (Tatar) [name] is returned.
  String localizedName(AppLocale locale) {
    if (locale == AppLocale.russian) {
      final russian = nameRu?.trim();
      if (russian != null && russian.isNotEmpty) return russian;
    }
    return name;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    nameRu,
    slug,
    isVisible,
    sortOrder,
    createdAt,
    updatedAt,
    backgroundImage,
    isDefaultForPhoto,
  ];
}
