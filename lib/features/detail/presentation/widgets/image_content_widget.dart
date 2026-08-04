import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tatislam_app/core/services/image_dimensions_service.dart';
import 'package:tatislam_app/core/storage/media_storage_repository.dart';
import 'package:tatislam_app/core/widgets/glass_container.dart';
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

/// Renders an [ImageContentBlock] with a tappable preview that opens
/// [ImageViewerScreen] on full screen.
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

  @override
  void initState() {
    super.initState();
    _dimensionsService = widget.dimensionsService ?? ImageDimensionsService();
    _resolveDimensions();
  }

  @override
  void didUpdateWidget(ImageContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.imagePath != widget.block.imagePath) {
      _dimensionsService = widget.dimensionsService ?? _dimensionsService;
      _imageSize = _dimensionsService.cached(_imageKey);
      _resolveDimensions();
    }
  }

  String get _imageKey =>
      widget.mediaStorage.publicUrlFor(widget.block.imagePath);

  Future<void> _resolveDimensions() async {
    final size = await _dimensionsService.resolve(
      key: _imageKey,
      provider: CachedNetworkImageProvider(_imageKey),
    );
    if (!mounted) return;
    if (size != null && size != _imageSize) {
      setState(() => _imageSize = size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageKey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        opacity: _glassOpacity,
        borderRadius: _glassRadius,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(imageUrl: imageUrl),
                ),
              );
            },
            child: _buildImageArea(context, imageUrl),
          ),
        ),
      ),
    );
  }

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
      color: Colors.white.withValues(alpha: 0.08),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
