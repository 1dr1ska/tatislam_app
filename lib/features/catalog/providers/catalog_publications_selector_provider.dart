import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/catalog/providers/catalog_favorites_provider.dart';
import 'package:tatislam_app/features/catalog/domain/entities/catalog_mode.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/catalog_mode_provider.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/selected_section_provider.dart';
import 'package:tatislam_app/features/publications/data/publication_providers.dart';

/// Provider that selects publications based on the current catalog mode and selected section
final catalogPublicationsSelectorProvider = FutureProvider<List<Publication>>((ref) async {
  final mode = ref.watch(catalogModeProvider);
  final selectedSection = ref.watch(selectedSectionProvider);
  
  if (mode == CatalogMode.favorites) {
    final favorites = await ref.watch(catalogFavoritesProvider.future);
    // Filter favorites by selected section if one is selected
    if (selectedSection != null) {
      final getPublications = ref.watch(getPublicationsWithFiltersProvider);
      final sectionPublications = await getPublications(sectionId: selectedSection.id);
      final favoriteIds = favorites.map((pub) => pub.id).toSet();
      return sectionPublications.where((pub) => favoriteIds.contains(pub.id)).toList();
    }
    return favorites;
  } else {
    final getPublications = ref.watch(getPublicationsWithFiltersProvider);
    final sectionId = selectedSection?.id;
    return await getPublications(sectionId: sectionId);
  }
});
