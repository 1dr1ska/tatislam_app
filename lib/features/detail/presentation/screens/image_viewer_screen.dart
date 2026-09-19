import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/providers/locale_provider.dart';
import 'package:tatislam_app/core/widgets/network_image.dart' show appWebImageRenderMethod;
import 'package:tatislam_app/features/detail/domain/services/file_transfer_service.dart';
import 'package:tatislam_app/features/detail/presentation/providers/file_transfer_provider.dart';

const Color _closeOverlayColor = Colors.black45;

class ImageViewerScreen extends ConsumerStatefulWidget {
  /// Backwards-compatible single photo URL. When [imageUrls] is empty, the
  /// viewer shows a single image (legacy behaviour). When set, it is treated
  /// as the sole member of [imageUrls].
  final String imageUrl;

  /// The full ordered photo list. Used as-is for the gallery; the same list
  /// powers the album preview grid and the full-screen gallery.
  final List<String> imageUrls;

  /// Which photo of [imageUrls] to open first (when several photos exist).
  final int initialIndex;

  /// Suggested file name for download/share; derived from the current URL
  /// when null.
  final String? fileName;

  /// Optional custom close handler. Defaults to `Navigator.pop` (used when the
  /// viewer is pushed onto the Navigator directly, e.g. from the grid card).
  /// Pass a go_router-aware callback when the viewer is hosted inside a route.
  final VoidCallback? onClose;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.imageUrls = const <String>[],
    this.initialIndex = 0,
    this.fileName,
    this.onClose,
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  bool _isDownloading = false;
  bool _isSharing = false;
  late int _currentIndex;

  AppLocalizations get t => AppLocalizations.fromLocale(
    ref.read(localeProvider),
  );

  /// The full ordered photo list. Legacy callers that only pass [imageUrl]
  /// get a one-element list.
  List<String> get _urls =>
      widget.imageUrls.isNotEmpty ? widget.imageUrls : [widget.imageUrl];

  String get _currentUrl => _urls[_currentIndex];

  String get _name =>
      widget.fileName ?? deriveFileName(_currentUrl, fallback: 'photo.jpg');

  @override
  void initState() {
    super.initState();
    _resetIndex();
  }

  @override
  void didUpdateWidget(ImageViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetIndex();
  }

  void _resetIndex() {
    var index = widget.initialIndex;
    if (index < 0) index = 0;
    final maxIndex = _urls.length - 1;
    if (index > maxIndex) index = maxIndex;
    _currentIndex = index;
  }

  void _goTo(int index) {
    if (index < 0 || index >= _urls.length) return;
    setState(() => _currentIndex = index);
  }

  Future<void> _handleDownload() async {
    if (_isSharing) return;
    setState(() => _isDownloading = true);
    try {
      final service = ref.read(fileTransferServiceProvider);
      final result = await service.saveFile(
        url: _currentUrl,
        fileName: _name,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      switch (result.status) {
        case FileSaveStatus.saved:
          messenger.showSnackBar(SnackBar(content: Text(t.photoDownloaded)));
        case FileSaveStatus.canceled:
          break; // User closed the dialog — no message needed.
        case FileSaveStatus.unavailable:
        case FileSaveStatus.error:
          messenger.showSnackBar(
            SnackBar(content: Text(t.photoDownloadError)),
          );
      }
    } catch (e) {
      debugPrint('Error downloading photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.photoDownloadError)));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _handleShare() async {
    if (_isDownloading) return;
    setState(() => _isSharing = true);
    try {
      final service = ref.read(fileTransferServiceProvider);
      final result = await service.shareFile(
        url: _currentUrl,
        fileName: _name,
      );
      if (!mounted) return;
      if (!result.shared) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.photoShareError)));
      }
    } catch (e) {
      debugPrint('Error sharing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.photoShareError)));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Fullscreen image viewer (single photo keeps the original
            // InteractiveViewer with pinch-zoom; albums swipe between pages).
            _urls.length > 1
                ? _buildGallery(context)
                : Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: CachedNetworkImage(
                        imageUrl: _currentUrl,
                        fit: BoxFit.contain,
                        imageRenderMethodForWeb: appWebImageRenderMethod,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),

            // "N / M" position counter for albums.
            if (_urls.length > 1)
              Positioned(
                top: 18,
                left: 16,
                child: _buildCounter(),
              ),

            // Top-right controls: download + share + close (high contrast).
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOverlayIconButton(
                    tooltip: t.download,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 24,
                          ),
                    onTap: _isDownloading || _isSharing
                        ? null
                        : _handleDownload,
                  ),
                  const SizedBox(width: 8),
                  _buildOverlayIconButton(
                    tooltip: t.share,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 24,
                          ),
                    onTap: _isDownloading || _isSharing ? null : _handleShare,
                  ),
                  const SizedBox(width: 8),
                  _buildOverlayIconButton(
                    tooltip: t.cancelAction,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onTap: widget.onClose ?? () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Swipeable gallery: a horizontal drag flips the photo (telegram-style).
  /// Uses the same ordered URL list as the album preview.
  Widget _buildGallery(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (_isDownloading || _isSharing) return;
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -150) {
          _goTo(_currentIndex + 1); // swiped left → next photo
        } else if (velocity > 150) {
          _goTo(_currentIndex - 1); // swiped right → previous photo
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // A new key per index forces the transition between photos.
        child: Center(
          key: Key('photo-$_currentIndex'),
          child: CachedNetworkImage(
            imageUrl: _currentUrl,
            fit: BoxFit.contain,
            imageRenderMethodForWeb: appWebImageRenderMethod,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  /// Position indicator `2 / 5` for albums.
  Widget _buildCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _closeOverlayColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${_currentIndex + 1} / ${_urls.length}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  /// A tappable control with a dark backdrop so it stays visible on any
  /// image (including bright/white backgrounds).
  Widget _buildOverlayIconButton({
    required String tooltip,
    required Widget icon,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _closeOverlayColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
