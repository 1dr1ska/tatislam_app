import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/favorites/data/favorites_providers.dart';
import 'package:tatislam_app/features/catalog/presentation/providers/catalog_favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сайланганнар'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              // TODO: Implement sync with server
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(refreshFavoritesProvider)();
        },
        child: _buildFavoritesList(context, ref, favoritesAsync),
      ),
    );
  }

  Widget _buildFavoritesList(BuildContext context, WidgetRef ref, AsyncValue<List<Publication>> favoritesAsync) {
    return favoritesAsync.when(
      data: (publications) {
        if (publications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.noPublications,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Сайланган мәкаләләрне бу киләчәк',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: publications.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final publication = publications[index];
            return _PublicationCard(
              publication: publication,
              onRemoveFavorite: () {
                ref.read(removeFavoriteProvider)(publication.id);
                // Invalidate related providers after a short delay to avoid build conflicts
                Future.microtask(() {
                  ref.invalidate(favoritesProvider);
                  ref.invalidate(catalogFavoritesProvider);
                });
              },
            );
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
              onPressed: () => ref.invalidate(favoritesProvider),
              child: Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicationCard extends StatelessWidget {
  final Publication publication;
  final VoidCallback onRemoveFavorite;

  const _PublicationCard({
    required this.publication,
    required this.onRemoveFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              GoRouter.of(context).go(
                '/publication/${publication.id}?source=favorites',
              );
            },
            child: Column(
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
                          ? Image.network(
                              publication.coverImagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                const Center(child: Icon(Icons.image_not_supported, size: 32)),
                            )
                          : const Center(child: Icon(Icons.image, size: 32, color: AppColors.primary)),
                    ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(publication.publishedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.star, color: Colors.amber),
                            onPressed: onRemoveFavorite,
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
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин. элек';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} сәг. элек';
    } else {
      return '${diff.inDays} көн элек';
    }
  }
}