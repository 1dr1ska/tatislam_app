import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Provider that returns the [Section] for a given [sectionId].
/// Used by the detail screen to determine the publication's background.
final sectionByIdProvider = Provider.family<Section?, String?>((
  ref,
  sectionId,
) {
  if (sectionId == null || sectionId.isEmpty) return null;
  final sections = ref.watch(sectionsProvider);
  final section = sections.where((s) => s.id == sectionId).firstOrNull;
  return section;
});
