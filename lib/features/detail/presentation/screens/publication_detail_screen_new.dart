import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/services/image_dimensions_service.dart';
import 'package:tatislam_app/core/storage/storage_providers.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/utils/date_format.dart';
import 'package:tatislam_app/core/utils/responsive.dart';
import 'package:tatislam_app/features/favorites/providers/favorites_provider.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';
import 'package:tatislam_app/features/publications/domain/entities/local_media_resolver.dart';
import 'package:tatislam_app/features/publications/domain/entities/publication.dart';
import 'package:tatislam_app/features/publications/domain/entities/video_source_type.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_size_info.dart';
import 'package:tatislam_app/features/saved_publications/domain/entities/download_status.dart';
import 'package:tatislam_app/features/saved_publications/presentation/providers/saved_publications_providers.dart';
import 'package:tatislam_app/features/publications/presentation/widgets/app_background.dart';
import 'package:tatislam_app/features/publications/providers/publications_provider.dart';
import 'package:tatislam_app/features/publications/providers/section_background_provider.dart';
import 'package:tatislam_app/features/detail/presentation/screens/image_viewer_screen.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/text_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/image_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/video_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/audio_content_widget.dart';
import 'package:tatislam_app/features/detail/presentation/widgets/file_content_widget.dart';

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

  Widget _buildContentBlock(
    ContentBlock block,
    MediaStorageRepository mediaStorage,
    String? trackTitle,
    LocalMediaResolver? localMedia,
    bool offline,
  ) {
    final child = switch (block) {
      TextContentBlock() => TextContentWidget(block: block),
      ImageContentBlock() => ImageContentWidget(
        block: block,
        mediaStorage: mediaStorage,
        dimensionsService: _dimensionsService,
        localMedia: localMedia,
      ),
      // External videos (YouTube/RuTube/direct) stay online-only — when reading
      // a saved copy they are skipped (the top notice explains why). Uploaded
      // videos that were downloaded for offline use play from the local file.
      VideoContentBlock() when offline =>
          _isOfflinePlayableVideo(block, localMedia)
              ? VideoContentWidget(
                  block: block,
                  mediaStorage: mediaStorage,
                  localMedia: localMedia,
                )
              : const SizedBox.shrink(),
      VideoContentBlock() => VideoContentWidget(
          block: block,
          mediaStorage: mediaStorage,
          localMedia: localMedia,
        ),
      AudioContentBlock() => AudioContentWidget(
        block: block,
        mediaStorage: mediaStorage,
        localMedia: localMedia,
        trackTitle: trackTitle,
      ),
      FileContentBlock() => FileContentWidget(
        block: block,
        mediaStorage: mediaStorage,
        localMedia: localMedia,
      ),
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

  /// Whether an uploaded video has a locally downloaded copy, so it can be
  /// played offline instead of being skipped.
  bool _isOfflinePlayableVideo(
    VideoContentBlock block,
    LocalMediaResolver? localMedia,
  ) {
    if (block.source != VideoSourceType.upload) return false;
    final path = block.videoPath ?? '';
    if (path.isEmpty) return false;
    return (localMedia?.call(path) ?? '').isNotEmpty;
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
              // Save/offline button — reactive via provider
              _SavePublicationButton(publicationId: widget.publicationId),
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
    final asyncPublication = ref.watch(
      publicationDetailProvider(widget.publicationId),
    );
    final mediaStorage = ref.watch(mediaStorageRepositoryProvider);

    // Offline copy resolution: when a saved copy exists it is preferred so the
    // screen is readable without a network connection.
    final asyncOffline = ref.watch(
      savedPublicationOfflineDetailProvider(widget.publicationId),
    );
    final offlineDetail = asyncOffline.asData?.value;
    final fromLocal = offlineDetail != null;
    final LocalMediaResolver? localMedia;
    if (fromLocal) {
      final detail = offlineDetail;
      localMedia = (String storagePath) => detail.mediaFiles[storagePath];
    } else {
      localMedia = null;
    }

    // The effective detail object (both [PublicationDetail] and
    // [OfflinePublicationDetail] expose `.publication` and `.blocks`).
    final dynamic effectiveDetail = fromLocal
        ? offlineDetail
        : asyncPublication.asData?.value;
    final hasOnlineVideo = offlineDetail?.hasOnlineVideo ?? false;

    String? backgroundImage;
    String? publicationTitle;
    Publication? photoPublication;
    if (effectiveDetail != null) {
      final publication = effectiveDetail.publication;
      publicationTitle = publication.title;
      backgroundImage = ref
          .watch(sectionByIdProvider(publication.primarySectionId))
          ?.backgroundImage;
      // У фото-публикаций нет контент-блоков — они всегда открываются
      // полноэкранным просмотрщиком (как из сетки, так и с push-тапа).
      if (publication.type == 'photo' &&
          publication.photoPath != null &&
          publication.photoPath!.isNotEmpty) {
        photoPublication = publication;
      }
    }

    if (photoPublication != null) {
      final photoPath = photoPublication.photoPath!;
      return ImageViewerScreen(
        imageUrl:
            localMedia?.call(photoPath) ?? mediaStorage.publicUrlFor(photoPath),
        fileName: photoPath.split('/').last,
        onClose: () => _navigateBackSafely(context),
      );
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
              await ref.read(
                publicationDetailProvider(widget.publicationId).future,
              );
            },
            child: fromLocal
                ? _buildEffectiveContent(
                    context,
                    effectiveDetail,
                    mediaStorage,
                    localMedia,
                    hasOnlineVideo,
                    fromLocal,
                  )
                : asyncPublication.when(
                    data: (publication) => effectiveDetail == null
                        ? _buildNullState(context)
                        : _buildEffectiveContent(
                            context,
                            effectiveDetail,
                            mediaStorage,
                            localMedia,
                            hasOnlineVideo,
                            fromLocal,
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => _buildErrorState(context),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEffectiveContent(
    BuildContext context,
    dynamic effectiveDetail,
    MediaStorageRepository mediaStorage,
    LocalMediaResolver? localMedia,
    bool hasOnlineVideo,
    bool fromLocal,
  ) {
    final isWide =
        ResponsiveBreakpoints.isTablet(context) ||
        ResponsiveBreakpoints.isCompactLandscape(context);
    final horizontalPadding = isWide ? 32.0 : 16.0;

    return _buildContent(
      context,
      effectiveDetail,
      mediaStorage,
      horizontalPadding,
      localMedia,
      fromLocal,
      hasOnlineVideo,
    );
  }

  Widget _buildNullState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(ref).errorLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(ref).errorLoading),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(
                  publicationDetailProvider(widget.publicationId),
                ),
                child: Text(AppLocalizations.of(ref).retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    dynamic publication,
    MediaStorageRepository mediaStorage,
    double horizontalPadding,
    LocalMediaResolver? localMedia,
    bool offline,
    bool hasOnlineVideo,
  ) {
    const double verticalPadding = 24;

    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        // The glass panel hugs its content instead of stretching to the full
        // screen height. The minimum height below only guarantees that short
        // publications still fill a scrollable viewport (so that
        // pull-to-refresh works), while the panel itself stays compact and
        // gets vertically centered on the screen.
        final remainingHeight =
            viewportConstraints.maxHeight - verticalPadding * 2;
        final minHeight = remainingHeight > 0 ? remainingHeight : 0.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
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
                        color: Colors.white.withValues(
                          alpha: _detailGlassOpacity,
                        ),
                        borderRadius: BorderRadius.circular(_detailGlassRadius),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: _detailGlassBorderOpacity,
                          ),
                          width: _detailGlassBorderWidth,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // When reading a saved copy we skip video blocks, so
                          // show a notice when the publication had any video.
                          if (offline && hasOnlineVideo)
                            _buildOfflineVideoNotice(context),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFFFEFEF7),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                // Publication date
                                Text(
                                  formatRelativeDate(
                                    publication.publication.publishedAt,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Content blocks
                          ...publication.blocks.map(
                            (block) => _buildContentBlock(
                              block,
                              mediaStorage,
                              publication.publication.title,
                              localMedia,
                              offline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflineVideoNotice(BuildContext context) {
    final t = AppLocalizations.of(ref);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_off_outlined, size: 18, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.savedOfflineVideoNotice,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
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

/// AppBar save-for-offline button — reactive via
/// [savedPublicationStateProvider]. Shows download progress while saving and
/// lets the user cancel or remove the saved copy.
class _SavePublicationButton extends ConsumerWidget {
  final String publicationId;

  const _SavePublicationButton({required this.publicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      savedPublicationStateProvider(publicationId),
    );
    final t = AppLocalizations.of(ref);

    final Widget icon;
    final String tooltip;
    final VoidCallback? onTap;

    switch (state.status) {
      case DownloadStatus.notSaved:
        icon = Icon(
          Icons.download_outlined,
          color: Colors.white.withValues(alpha: 0.85),
          size: 20,
        );
        tooltip = t.saveForOffline;
        onTap = () => _requestDownload(context, ref, t);
      case DownloadStatus.downloading:
        icon = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        );
        tooltip = t.cancelDownload;
        onTap = () =>
            ref.read(savedPublicationStateProvider(publicationId).notifier)
                .cancel();
      case DownloadStatus.saved:
        icon = Icon(
          Icons.download_done,
          color: Colors.greenAccent,
          size: 20,
        );
        tooltip = t.removeFromSaved;
        onTap = () => _confirmRemove(context, ref, t);
      case DownloadStatus.failed:
        icon = Icon(
          Icons.error_outline,
          color: AppColors.error,
          size: 20,
        );
        tooltip = t.savedDownloadFailed;
        onTap = () => _requestDownload(context, ref, t);
    }

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
          icon: icon,
          tooltip: tooltip,
          onPressed: onTap,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  /// Asks for confirmation before starting a download. Shows the estimated
  /// size of the offline copy and warns that RuTube / YouTube videos are not
  /// saved (they remain online-only).
  Future<void> _requestDownload(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    // While the size is estimated (network HEAD requests), show a loading
    // indicator so the tap gives immediate feedback.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    DownloadSizeInfo? sizeInfo;
    try {
      final detail = await ref
          .read(publicationDetailProvider(publicationId).future);
      sizeInfo = detail == null
          ? null
          : await ref
              .read(savedPublicationRepositoryProvider)
              .computeSize(detail);
    } catch (_) {
      sizeInfo = null;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close loading dialog
    if (!context.mounted) return;

    final confirmed = await _showDownloadConfirmation(context, t, sizeInfo);
    if (confirmed != true) return;

    await ref.read(savedPublicationStateProvider(publicationId).notifier)
        .start();
  }

  Future<bool?> _showDownloadConfirmation(
    BuildContext context,
    AppLocalizations t,
    DownloadSizeInfo? sizeInfo,
  ) {
    final sizeText = sizeInfo == null || sizeInfo.hasUnknownSize
        ? t.downloadUnknownSizeMessage
        : '${t.downloadSizeLabel} ${_formatBytes(sizeInfo.totalBytes)}';

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.downloadConfirmationTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.downloadConfirmationMessage),
            const SizedBox(height: 10),
            Text(
              sizeText,
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (sizeInfo?.hasVideo ?? false) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.download_done,
                    size: 20,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.savedOfflineVideoIncluded,
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (sizeInfo?.hasOnlineVideo ?? false) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.downloadVideoWarning,
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.downloadAction),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.deleteConfirmation),
        content: Text(t.removeSavedOffline),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(savedPublicationStateProvider(publicationId).notifier)
        .remove();
    messenger.showSnackBar(
      SnackBar(content: Text(t.publicationDeleted)),
    );
  }
}
