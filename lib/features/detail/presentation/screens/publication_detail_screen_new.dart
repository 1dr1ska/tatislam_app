import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/providers/publications_provider.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/text_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/image_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/video_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/audio_content_widget.dart';

class PublicationDetailScreen extends ConsumerStatefulWidget {
  final String publicationId;
  final String? sourceScreen;
  final String? selectedSectionId;
  final String? catalogMode;

  const PublicationDetailScreen({
    super.key,
    required this.publicationId,
    this.sourceScreen,
    this.selectedSectionId,
    this.catalogMode,
  });

  @override
  ConsumerState<PublicationDetailScreen> createState() =>
      _PublicationDetailScreenState();
}

class _PublicationDetailScreenState
    extends ConsumerState<PublicationDetailScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadPublication();
  }

  Future<void> _loadPublication() async {
    final asyncPublication = await ref.read(
      publicationDetailProvider(widget.publicationId).future,
    );

    if (asyncPublication != null && mounted) {
      final favoritesAsync = ref.read(favoritesProvider);
      final favorites = favoritesAsync.asData?.value ?? [];
      final isFav =
          favorites.any((p) => p.id == asyncPublication.publication.id);
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final toggleFavorite = ref.read(toggleFavoriteProvider);
    final newFavoriteState = await toggleFavorite(widget.publicationId);
    if (mounted) {
      setState(() {
        _isFavorite = newFavoriteState;
      });
    }
    // Invalidate favorites cache so other screens stay in sync
    Future.microtask(() {
      ref.invalidate(favoritesProvider);
    });
  }

  /// Safely navigate back, falling back to go to home if pop fails.
  void _navigateBackSafely(BuildContext context) {
    try {
      if (GoRouter.of(context).canPop()) {
        GoRouter.of(context).pop();
      } else {
        GoRouter.of(context).go('/');
      }
    } catch (_) {
      GoRouter.of(context).go('/');
    }
  }

  Widget _buildContentBlock(
    ContentBlock block,
    MediaStorageRepository mediaStorage,
  ) {
    return switch (block) {
      TextContentBlock() => TextContentWidget(block: block),
      ImageContentBlock() =>
        ImageContentWidget(block: block, mediaStorage: mediaStorage),
      VideoContentBlock() => VideoContentWidget(block: block),
      AudioContentBlock() =>
        AudioContentWidget(block: block, mediaStorage: mediaStorage),
    };
  }

  @override
  Widget build(BuildContext context) {
    final asyncPublication =
        ref.watch(publicationDetailProvider(widget.publicationId));
    final mediaStorage = ref.watch(mediaStorageRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _navigateBackSafely(context),
        ),
        title: Text(AppStrings.catalogTab),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: asyncPublication.when(
        data: (publication) {
          if (publication == null) {
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
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  publication.publication.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Content blocks
                ...publication.blocks.map(
                  (block) => _buildContentBlock(block, mediaStorage),
                ),

                const SizedBox(height: 24),

                // Description
                if (publication.publication.description.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Тасвирлама',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(publication.publication.description),
                    ],
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(AppStrings.errorLoading),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPublication,
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}