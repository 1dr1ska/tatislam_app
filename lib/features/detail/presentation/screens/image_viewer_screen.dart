import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/core/providers/locale_provider.dart';
import 'package:tatislam_app/features/detail/domain/services/file_transfer_service.dart';
import 'package:tatislam_app/features/detail/presentation/providers/file_transfer_provider.dart';

const Color _closeOverlayColor = Colors.black45;

class ImageViewerScreen extends ConsumerStatefulWidget {
  final String imageUrl;

  /// Suggested file name for download/share; derived from [imageUrl] when null.
  final String? fileName;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.fileName,
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  bool _isDownloading = false;
  bool _isSharing = false;

  AppLocalizations get t => AppLocalizations.fromLocale(
    ref.read(localeProvider),
  );

  String get _name =>
      widget.fileName ?? deriveFileName(widget.imageUrl, fallback: 'photo.jpg');

  Future<void> _handleDownload() async {
    if (_isSharing) return;
    setState(() => _isDownloading = true);
    try {
      final service = ref.read(fileTransferServiceProvider);
      final result = await service.saveFile(
        url: widget.imageUrl,
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
        url: widget.imageUrl,
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
            // Fullscreen image viewer
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
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
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
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
