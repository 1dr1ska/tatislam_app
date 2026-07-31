import 'package:tatislam_app/core/services/local_storage_service.dart';
import 'package:tatislam_app/features/sections/data/models/section_model.dart';

/// Local (Hive) cache for sections.
///
/// Stores the full list of sections as a JSON-encoded list in the dedicated
/// `sections_cache` Hive box. This allows the UI to bootstrap immediately
/// without waiting for the network.
class SectionLocalDataSource {
  static const String _key = 'sections';

  /// Reads the cached section list, or returns an empty list if nothing
  /// has been cached yet.
  List<SectionModel> getCachedSections() {
    try {
      final box = LocalStorageService.sectionsCacheBox;
      final raw = box.get(_key) as List<dynamic>?;
      if (raw == null) return [];
      return raw
          .cast<Map<String, dynamic>>()
          .map((json) => SectionModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Overwrites the local cache with [sections].
  void cacheSections(List<SectionModel> sections) {
    try {
      final box = LocalStorageService.sectionsCacheBox;
      box.put(_key, sections.map((s) => s.toJson()).toList());
    } catch (_) {
      // Silently fail — cache is best-effort
    }
  }

  /// Returns `true` if there is at least one section in the cache.
  bool hasCachedData() {
    try {
      final box = LocalStorageService.sectionsCacheBox;
      return box.containsKey(_key);
    } catch (_) {
      return false;
    }
  }
}
