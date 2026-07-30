import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/presentation/widgets/app_background.dart';
import 'package:tatislam_app/features/publications/providers/publications_provider.dart';
import 'package:tatislam_app/features/publications/providers/section_background_provider.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/text_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/image_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/video_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/audio_content_widget.dart';

/// Unified glassmorphism constants matching the main screen.
const double _detailGlassBlur = 18;
const double _detailGlassOpacity = 0.45;
const double _detailGlassBorderOpacity = 0.35;
const double _detailGlassBorderWidth = 0.8;
const double _detailGlassRadius = 16;
const double _detailPadding = 24;

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
    Future.microtask(() {
      ref.invalidate(favoritesProvider);
    });
  }

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

    String? backgroundImage;
    String? publicationTitle;
    if (asyncPublication is AsyncData && asyncPublication.value != null) {
      final publication = asyncPublication.value!.publication;
      publicationTitle = publication.title;
      final sectionAsync = ref.watch(sectionByIdProvider(publication.primarySectionId));
      backgroundImage = sectionAsync.asData?.value?.backgroundImage;
    }

    return Stack(
      children: [
        AppBackground(imagePath: backgroundImage),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AppBar(
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  titleSpacing: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _navigateBackSafely(context),
                  ),
                  title: Text(
                    publicationTitle ?? '',
                    style: const TextStyle(
                      color: Color(0xFFF8F7F2),
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                            width: 0.8,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isFavorite ? Icons.star : Icons.star_border,
                            color: _isFavorite
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.85),
                            size: 20,
                          ),
                          onPressed: _toggleFavorite,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_detailGlassRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _detailGlassBlur,
                      sigmaY: _detailGlassBlur,
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: _detailGlassOpacity),
                        borderRadius: BorderRadius.circular(_detailGlassRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: _detailGlassBorderOpacity),
                          width: _detailGlassBorderWidth,
                        ),
                      ),
                      padding: const EdgeInsets.all(_detailPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Content blocks (title removed — now in AppBar)
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
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1A1A2E),
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  publication.publication.description,
                                  style: const TextStyle(
                                    color: Color(0xFF2D2D44),
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
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
        ),
      ],
    );
  }
}