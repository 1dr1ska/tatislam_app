import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_strings.dart';
import 'package:tatislam_app/core/services/image_dimensions_service.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
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
  final ImageDimensionsService _dimensionsService = ImageDimensionsService();

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

  Widget _buildContentBlock(
    ContentBlock block,
    MediaStorageRepository mediaStorage,
  ) {
    final child = switch (block) {
      TextContentBlock() => TextContentWidget(block: block),
      ImageContentBlock() => ImageContentWidget(
          block: block,
          mediaStorage: mediaStorage,
          dimensionsService: _dimensionsService,
        ),
      VideoContentBlock() => VideoContentWidget(block: block),
      AudioContentBlock() =>
        AudioContentWidget(block: block, mediaStorage: mediaStorage),
    };

    // Photos and videos span the full card width (edge-to-edge). All other
    // blocks keep the standard horizontal padding.
    final isEdgeToEdge =
        block is ImageContentBlock || block is VideoContentBlock;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isEdgeToEdge ? 0 : _detailPadding,
      ),
      child: child,
    );
  }

  /// The detail screen's AppBar. Hidden in landscape so the media content
  /// (photos/videos) uses the full available screen height.
  PreferredSize? _buildAppBar(BuildContext context, String? publicationTitle) {
    return PreferredSize(
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFFF8F7F2),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            actions: [
              // Favorite button — reactive via provider
              _FavoriteButton(publicationId: widget.publicationId),
            ],
          ),
        ),
      ),
    );
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
      backgroundImage = ref.watch(
        sectionByIdProvider(publication.primarySectionId),
      )?.backgroundImage;
    }

    return Stack(
      children: [
        AppBackground(imagePath: backgroundImage),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(context, publicationTitle),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(publicationDetailProvider(widget.publicationId));
              await ref.read(publicationDetailProvider(widget.publicationId).future);
            },
            child: asyncPublication.when(
              data: (publication) {
                if (publication == null) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
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
                      ),
                    ),
                  );
                }

                final isWide = ResponsiveBreakpoints.isTablet(context) || ResponsiveBreakpoints.isCompactLandscape(context);
                final horizontalPadding = isWide ? 32.0 : 16.0;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
                  child: Align(
                    alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 860,
                          minHeight: MediaQuery.of(context).size.height,
                        ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and date keep the card's horizontal
                                // padding; media blocks span edge-to-edge.
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _detailPadding,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Full title — always visible, not truncated
                                      SelectableText(
                                        publication.publication.title,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          color: const Color(0xFFFEFEF7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Publication date
                                      Text(
                                        _formatDate(publication.publication.publishedAt),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Content blocks
                                ...publication.blocks.map(
                                  (block) => _buildContentBlock(block, mediaStorage),
                                ),
                                const SizedBox(height: 24),
                                // Description
                                if (publication.publication.description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: _detailPadding,
                                    ),
                                    child: Column(
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
                                        SelectableText(
                                          publication.publication.description,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFF2D2D44),
                                            height: 1.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(AppStrings.errorLoading),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(publicationDetailProvider(widget.publicationId)),
                          child: Text(AppStrings.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// AppBar favorite button — reactive via [favoritesIsFavoriteProvider].
class _FavoriteButton extends ConsumerWidget {
  final String publicationId;

  const _FavoriteButton({required this.publicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesIsFavoriteProvider(publicationId));

    return Padding(
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
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite
                ? Colors.amber
                : Colors.white.withValues(alpha: 0.85),
            size: 20,
          ),
          onPressed: () async {
            final toggleFavorite = ref.read(toggleFavoriteProvider);
            await toggleFavorite(publicationId);
            ref.invalidate(favoritesProvider);
          },
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}