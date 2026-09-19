import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tatislam_app/core/services/image_dimensions_service.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/widgets/glass_container.dart';
import 'package:tatislam_app/core/widgets/network_image.dart' show appWebImageRenderMethod;
import 'package:tatislam_app/features/detail/presentation/screens/image_viewer_screen.dart';
import 'package:tatislam_app/features/publications/domain/entities/content_block.dart';

/// Maximum photo height relative to the screen — very tall images (e.g. 1:3)
/// are clamped so they don't dominate the whole screen.
const double _maxHeightFraction = 0.65;

/// Minimum photo height in logical pixels — ultra-wide panoramas (e.g. 21:9
/// and wider) won't collapse into a thin strip.
const double _minHeight = 170;

const double _glassOpacity = 0.25;
const double _glassRadius = 12;

/// Gap between album tiles, in logical pixels.
const double _albumGap = 2;

/// Renders an [ImageContentBlock] as a Telegram-style album:
///
/// * one photo — the existing full-width preview sized to the photo's own
///   aspect ratio (kept visually identical);
/// * several photos — a compact grid of fixed-height tiles (`BoxFit.cover`
///   crops each photo into its cell, so there are no huge empty areas and it
///   scales down to narrow phones):
///
///   2 photos — `[ ][ ]`        3 photos — `[   ]` / `[ ][ ]`
///   4 photos — 2×2              5+ photos — 2×2 with a `+N` tile.
///
/// Tapping any photo opens [ImageViewerScreen] (a swipeable full-screen
/// gallery) positioned on that photo.
class ImageContentWidget extends StatefulWidget {
  final ImageContentBlock block;
  final MediaStorageRepository mediaStorage;

  /// Shared cache of image dimensions.
  final ImageDimensionsService? dimensionsService;

  const ImageContentWidget({
    super.key,
    required this.block,
    required this.mediaStorage,
    this.dimensionsService,
  });

  @override
  State<ImageContentWidget> createState() => _ImageContentWidgetState();
}

class _ImageContentWidgetState extends State<ImageContentWidget> {
  late final ImageDimensionsService _dimensionsService;
  Size? _imageSize;

  /// Public URLs of the block's non-empty photos (Storage paths resolved via
  /// [MediaStorageRepository.publicUrlFor]). Empty paths are skipped so a
  /// broken/absent entry never breaks the whole block.
  List<String> get _imageUrls =>
      widget.block.imagePaths
          .where((path) => path.isNotEmpty)
          .map((path) => widget.mediaStorage.publicUrlFor(path))
          .toList();

  /// URL of the single photo used to resolve its aspect ratio (albums use
  /// fixed-height tiles and don't need dimensions).
  String get _singleImageUrl {
    final paths = widget.block.imagePaths.where((path) => path.isNotEmpty);
    if (paths.isEmpty) return '';
    return widget.mediaStorage.publicUrlFor(paths.first);
  }

  @override
  void initState() {
    super.initState();
    _dimensionsService = widget.dimensionsService ?? ImageDimensionsService();
    _resolveDimensions();
  }

  @override
  void didUpdateWidget(ImageContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePaths(oldWidget.block.imagePaths, widget.block.imagePaths)) {
      _dimensionsService = widget.dimensionsService ?? _dimensionsService;
      _imageSize = null;
      _resolveDimensions();
    }
  }

  static bool _samePaths(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _resolveDimensions() async {
    // Only the single-photo layout sizes itself by the image's aspect ratio;
    // album tiles have fixed ratios and don't need dimensions.
    if (_imageUrls.length > 1) return;
    final imageUrl = _singleImageUrl;
    if (imageUrl.isEmpty) return;

    final size = await _dimensionsService.resolve(
      key: imageUrl,
      provider: CachedNetworkImageProvider(
        imageUrl,
        imageRenderMethodForWeb: appWebImageRenderMethod,
      ),
    );
    if (!mounted) return;
    if (size != null && size != _imageSize) {
      setState(() => _imageSize = size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _imageUrls;

    // Single photo keeps the original look (whole photo, its own aspect
    // ratio, whole-area tap target).
    final Widget child = imageUrls.length > 1
        ? _buildAlbum(context, imageUrls)
        : GestureDetector(
            onTap: () => _openViewer(context, imageUrls, 0),
            child: _buildImageArea(context, imageUrls.firstOrNull ?? ''),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }

  /// Opens the full-screen gallery on the photo at [index].
  void _openViewer(BuildContext context, List<String> imageUrls, int index) {
    Navigator.of(context).push(
      PageRouteBuilder(
        // Fade transition with a transparent background — the default
        // Material zoom transition flashes a white frame while the route is
        // being built.
        opaque: false,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ImageViewerScreen(
          // `imageUrl` is required for backwards compatibility with the
          // single-photo call sites; when `imageUrls` is non-empty the
          // viewer ignores it.
          imageUrl: imageUrls.firstOrNull ?? '',
          imageUrls: imageUrls,
          initialIndex: index,
        ),
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Album (2+ photos)
  // -------------------------------------------------------------------------

  Widget _buildAlbum(BuildContext context, List<String> imageUrls) {
    final count = imageUrls.length;
    if (count == 2) {
      return Row(
        spacing: _albumGap,
        children: [
          _buildAlbumTile(context, imageUrls, 0, aspectRatio: 1),
          _buildAlbumTile(context, imageUrls, 1, aspectRatio: 1),
        ],
      );
    }
    if (count == 3) {
      // One wide photo on top, two square tiles below.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: _albumGap,
        children: [
          _buildAlbumTile(context, imageUrls, 0, aspectRatio: 2),
          Row(
            spacing: _albumGap,
            children: [
              _buildAlbumTile(context, imageUrls, 1, aspectRatio: 1),
              _buildAlbumTile(context, imageUrls, 2, aspectRatio: 1),
            ],
          ),
        ],
      );
    }
    // 4 photos — a 2×2 grid; 5+ — the 4th tile shows a dim overlay with the
    // number of photos that did not fit.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _albumGap,
      children: [
        Row(
          spacing: _albumGap,
          children: [
            _buildAlbumTile(context, imageUrls, 0, aspectRatio: 1),
            _buildAlbumTile(context, imageUrls, 1, aspectRatio: 1),
          ],
        ),
        Row(
          spacing: _albumGap,
          children: [
            _buildAlbumTile(context, imageUrls, 2, aspectRatio: 1),
            count > 4
                ? _buildOverflowTile(context, imageUrls, 3, count - 4)
                : _buildAlbumTile(context, imageUrls, 3, aspectRatio: 1),
          ],
        ),
      ],
    );
  }

  /// A single square (or [aspectRatio]) tile. `Expanded` gives every tile in a
  /// row an equal share of the width, so heights stay uniform and there are no
  /// big empty areas regardless of the source photos' proportions.
  Widget _buildAlbumTile(
    BuildContext context,
    List<String> imageUrls,
    int index, {
    required double aspectRatio,
  }) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: GestureDetector(
          onTap: () => _openViewer(context, imageUrls, index),
          child: CachedNetworkImage(
            imageUrl: imageUrls[index],
            fit: BoxFit.cover,
            imageRenderMethodForWeb: appWebImageRenderMethod,
            fadeInDuration: const Duration(milliseconds: 300),
            fadeInCurve: Curves.easeIn,
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) =>
                const Icon(Icons.image, size: 64),
          ),
        ),
      ),
    );
  }

  /// The last tile of a 5+ album: the 4th photo dimmed with a `+N` badge
  /// (N = photos hidden beyond it).
  Widget _buildOverflowTile(
    BuildContext context,
    List<String> imageUrls,
    int index,
    int overflowCount,
  ) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: () => _openViewer(context, imageUrls, index),
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrls[index],
                  fit: BoxFit.cover,
                  imageRenderMethodForWeb: appWebImageRenderMethod,
                  fadeInDuration: const Duration(milliseconds: 300),
                  fadeInCurve: Curves.easeIn,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.image, size: 64),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
              Center(
                child: Text(
                  '+$overflowCount',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Single photo
  // -------------------------------------------------------------------------

  Widget _buildImageArea(BuildContext context, String imageUrl) {
    final imageSize = _imageSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        if (availableWidth <= 0) {
          return const SizedBox(width: double.infinity, height: _minHeight);
        }

        final double height;
        if (imageSize != null) {
          final aspectRatio = imageSize.width / imageSize.height;
          final naturalHeight = availableWidth / aspectRatio;
          final maxHeight =
              MediaQuery.of(context).size.height * _maxHeightFraction;
          height = naturalHeight.clamp(_minHeight, maxHeight);
        } else {
          height = availableWidth * (2 / 3);
        }

        return SizedBox(
          width: double.infinity,
          height: height,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            imageRenderMethodForWeb: appWebImageRenderMethod,
            fadeInDuration: const Duration(milliseconds: 300),
            fadeInCurve: Curves.easeIn,
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) =>
                const Icon(Icons.image, size: 64),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
