import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Provider that returns the [Section] for a given [sectionId].
/// Used by the detail screen to determine the publication's background.
final sectionByIdProvider =
    FutureProvider.family<Section?, String?>((ref, sectionId) async {
  if (sectionId == null || sectionId.isEmpty) return null;
  final sections = await ref.watch(sectionsProvider.future);
  debugPrint('SectionBackgroundProvider: looking for sectionId="$sectionId" in ${sections.length} sections');
  final section = sections.where((s) => s.id == sectionId).firstOrNull;
  debugPrint('SectionBackgroundProvider: found section="${section?.name}", background="${section?.backgroundImage}"');
  return section;
});