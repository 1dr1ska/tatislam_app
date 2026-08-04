import 'package:flutter_riverpod/legacy.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';

/// Provider for storing the currently selected section for filtering
final selectedSectionProvider = StateProvider<Section?>((ref) {
  return null; // Initially no section is selected
});
