import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/sections/domain/entities/section.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';
import 'package:tatislam_app/features/catalog/providers/catalog_publications_selector_provider.dart';
import 'package:tatislam_app/features/catalog/domain/entities/catalog_mode.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/catalog_mode_provider.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/selected_section_provider.dart';
import 'package:tatislam_app/features/catalog/providers/catalog_favorites_provider.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  bool _hasProcessedQueryParams = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Check for section parameter in route
    final routeState = GoRouterState.of(context);
    final sectionId = routeState.uri.queryParameters['section'];
    final modeParam = routeState.uri.queryParameters['mode'];
    
    // Set the selected section if provided
    if (sectionId != null && sectionId.isNotEmpty) {
      // We'll need to find the section by ID and set it
      // This would require a provider that can fetch sections by ID
    }
    
    // Set the mode if provided (only once)
    if (!_hasProcessedQueryParams && modeParam != null && modeParam.isNotEmpty) {
      final mode = CatalogMode.values.firstWhere(
        (m) => m.name == modeParam,
        orElse: () => CatalogMode.all,
      );
      // Use a delayed future to avoid modifying provider during build
      // Only set if the current mode is different
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentMode = ref.read(catalogModeProvider);
        if (currentMode != mode) {
          ref.read(catalogModeProvider.notifier).state = mode;
        }
        // Mark that we've processed the query parameters
        setState(() {
          _hasProcessedQueryParams = true;
        });
      });
    }
    
    final sectionsAsync = ref.watch(sectionsProvider);
    final mode = ref.watch(catalogModeProvider);
    final publicationsAsync = ref.watch(catalogPublicationsSelectorProvider);

    // Check if either provider is loading
    final isLoading = sectionsAsync.isLoading || publicationsAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.catalogTab),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<CatalogMode>(
              segments: const [
                ButtonSegment(
                  value: CatalogMode.all,
                  label: Text('Барлыгы'),
                ),
                ButtonSegment(
                  value: CatalogMode.favorites,
                  label: Text('Сайланганнар'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (Set<CatalogMode> newSelection) {
                if (newSelection.isNotEmpty) {
                  ref.read(catalogModeProvider.notifier).state = newSelection.first;
                }
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sectionsProvider);
          ref.invalidate(catalogPublicationsSelectorProvider);
          ref.invalidate(catalogFavoritesProvider);
          ref.invalidate(selectedSectionProvider);
          await Future.wait([
            ref.read(sectionsProvider.future),
            ref.read(catalogPublicationsSelectorProvider.future),
            ref.read(catalogFavoritesProvider.future),
          ]);
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section filters
                    _buildSectionFilters(ref, sectionsAsync),
                    const SizedBox(height: 16),
                    // Publications grid
                    _buildPublicationsGrid(context, ref, publicationsAsync),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionFilters(WidgetRef ref, AsyncValue<List<Section>> sectionsAsync) {
    final selectedSection = ref.watch(selectedSectionProvider);
    
    return sectionsAsync.when(
      data: (sections) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text('Все'),
                selected: selectedSection == null,
                onSelected: (selected) {
                  ref.read(selectedSectionProvider.notifier).state = null;
                },
              ),
              ...sections.map((section) => FilterChip(
                    label: Text(section.name),
                    selected: selectedSection?.id == section.id,
                    onSelected: (selected) {
                      ref.read(selectedSectionProvider.notifier).state = section;
                    },
                  )),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(AppStrings.errorLoading),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(sectionsProvider),
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublicationsGrid(BuildContext context, WidgetRef ref, AsyncValue<List<Publication>> publicationsAsync) {
    return publicationsAsync.when(
      data: (publications) {
        if (publications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                  Text(
                    AppStrings.noPublications,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: publications.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final publication = publications[index];
            return _PublicationCard(publication: publication);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(AppStrings.errorLoading),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(catalogPublicationsSelectorProvider),
              child: Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicationCard extends ConsumerWidget {
  final Publication publication;

  const _PublicationCard({required this.publication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesIsFavoriteProvider(publication.id));
    final mediaStorage = ref.watch(mediaStorageRepositoryProvider);
    
    return GestureDetector(
      onTap: () {
        // Get current section and mode for context
        final selectedSection = ref.read(selectedSectionProvider);
        final mode = ref.read(catalogModeProvider);
        
        GoRouter.of(context).go(
          '/publication/${publication.id}?source=catalog&section=${selectedSection?.id ?? ''}&mode=${mode.name}',
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Container(
                        height: 80,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: publication.coverImagePath.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: mediaStorage.publicUrlFor(publication.coverImagePath),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => 
                                  const Icon(Icons.image_not_supported, size: 32),
                              )
                            : const Icon(Icons.image, size: 32, color: AppColors.primary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            publication.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                ),
                                onPressed: () async {
                                  final toggleFavorite = ref.read(toggleFavoriteProvider);
                                  await toggleFavorite(publication.id);
                                  // Invalidate related providers after a short delay to avoid build conflicts
                                  Future.microtask(() {
                                    ref.invalidate(favoritesProvider);
                                    ref.invalidate(catalogFavoritesProvider);
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
