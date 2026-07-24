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

  const Section({
    required this.id,
    required this.name,
    required this.slug,
    required this.isVisible,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  Section copyWith({
    String? name,
    String? slug,
    bool? isVisible,
    int? sortOrder,
  }) {
    return Section(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, slug, isVisible, sortOrder, createdAt, updatedAt];
}
