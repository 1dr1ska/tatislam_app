import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/home/providers/home_provider.dart';
import 'package:tatislam_app/features/home/data/home_providers.dart';
import 'package:tatislam_app/features/home/domain/entities/home_layout_mode.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/catalog_favorites_provider.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPublications = ref.watch(homePublicationsProvider);
    final layoutMode = ref.watch(homeLayoutModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.homeTab),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(homePublicationsProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<HomeLayoutMode>(
              segments: [
                ButtonSegment(
                  value: HomeLayoutMode.feed,
                  label: Text(AppStrings.feedMode),
                  icon: const Icon(Icons.list),
                ),
                ButtonSegment(
                  value: HomeLayoutMode.cards,
                  label: Text(AppStrings.cardsMode),
                  icon: const Icon(Icons.grid_view),
                ),
              ],
              selected: {layoutMode},
              onSelectionChanged: (Set<HomeLayoutMode> newSelection) {
                if (newSelection.isNotEmpty) {
                  ref.read(homeLayoutModeProvider.notifier).state = newSelection.first;
                }
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homePublicationsProvider);
          await ref.read(homePublicationsProvider.future);
        },
        child: Column(
          children: [
            Expanded(
              child: asyncPublications.when(
                data: (publications) {
                  if (publications.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return layoutMode == HomeLayoutMode.feed
                      ? _buildFeedLayout(context, publications, ref)
                      : _buildCardsLayout(context, publications, ref);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _buildErrorState(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Center(
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
            onPressed: () => ref.invalidate(homePublicationsProvider),
            child: Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedLayout(BuildContext context, List<Publication> publications, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: publications.length,
      itemBuilder: (context, index) {
        final publication = publications[index];
        return _FeedCard(publication: publication);
      },
    );
  }

  Widget _buildCardsLayout(BuildContext context, List<Publication> publications, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
      itemCount: publications.length,
      itemBuilder: (context, index) {
        final publication = publications[index];
        return _CardGridItem(publication: publication);
      },
    );
  }
}

class _FeedCard extends ConsumerWidget {
  final Publication publication;

  const _FeedCard({required this.publication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaStorage = ref.watch(mediaStorageRepositoryProvider);
    final isFavorite = ref.watch(favoritesIsFavoriteProvider(publication.id));
    
    return GestureDetector(
      onTap: () {
        GoRouter.of(context).go('/publication/${publication.id}');
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: publication.coverImagePath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: mediaStorage.publicUrlFor(publication.coverImagePath),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => 
                            const Center(child: Icon(Icons.image_not_supported, size: 48)),
                        )
                      : const Center(child: Icon(Icons.image, size: 48, color: AppColors.primary)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    publication.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          color: isFavorite ? Colors.amber : null,
                        ),
                        onPressed: () async {
                          final toggleFavorite = ref.read(toggleFavoriteProvider);
                          await toggleFavorite(publication.id);
                          Future.microtask(() {
                            ref.invalidate(favoritesProvider);
                            ref.invalidate(catalogFavoritesProvider);
                          });
                        },
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
  }
}

class _CardGridItem extends ConsumerWidget {
  final Publication publication;

  const _CardGridItem({required this.publication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaStorage = ref.watch(mediaStorageRepositoryProvider);
    final isFavorite = ref.watch(favoritesIsFavoriteProvider(publication.id));
    
    return GestureDetector(
      onTap: () {
        GoRouter.of(context).go('/publication/${publication.id}');
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
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: publication.coverImagePath.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: mediaStorage.publicUrlFor(publication.coverImagePath),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => 
                                    const Center(child: Icon(Icons.image_not_supported, size: 32)),
                                )
                              : const Center(child: Icon(Icons.image, size: 32, color: AppColors.primary)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                                  isFavorite ? Icons.star : Icons.star_border,
                                  color: isFavorite ? Colors.amber : null,
                                ),
                                onPressed: () async {
                                  final toggleFavorite = ref.read(toggleFavoriteProvider);
                                  await toggleFavorite(publication.id);
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
