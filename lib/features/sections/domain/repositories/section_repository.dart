import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Boundary for all section-related admin & read operations.
abstract class SectionRepository {
  /// Returns sections ordered by [Section.sortOrder].
  /// When [includeHidden] is false (default, used by the public app),
  /// only visible sections are returned.
  Future<List<Section>> getSections({bool includeHidden = false});

  /// Creates a section. The slug is derived from [name] automatically.
  Future<Section> createSection(String name);

  Future<Section> renameSection(String id, String name);

  Future<Section> setVisibility(String id, bool isVisible);

  /// Deletes a section. Publications keep existing but lose this section
  /// membership (cascade defined at the DB level).
  Future<void> deleteSection(String id);

  /// Persists a full reorder. [orderedIds] must contain every section id
  /// exactly once, in the desired display order.
  Future<void> reorderSections(List<String> orderedIds);
  
  /// Moves a section up one position in the sort order.
  /// Returns the updated section, or null if the section cannot be moved up.
  Future<Section?> moveSectionUp(Section section);
  
  /// Moves a section down one position in the sort order.
  /// Returns the updated section, or null if the section cannot be moved down.
  Future<Section?> moveSectionDown(Section section);
}
