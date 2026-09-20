import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tatislam_app/core/widgets/network_image.dart'
    show appWebImageRenderMethod;

import 'app_image_local.dart'
    if (dart.library.js_interop) 'app_image_web.dart' as local_image;

/// An image that renders either a remote URL (via [CachedNetworkImage]) or a
/// local `file://` URI (the on-disk offline copy of a saved publication).
///
/// [CachedNetworkImage] fetches over HTTP and therefore cannot load `file://`
/// URIs — on mobile/desktop that used to fall into the broken-image error
/// widget. This widget transparently decodes the local file instead.
class AppImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext)? errorBuilder;
  final Duration fadeInDuration;
  final Curve fadeInCurve;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorBuilder,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeInCurve = Curves.easeIn,
  });

  bool get _isLocal => imageUrl.startsWith('file://');

  @override
  Widget build(BuildContext context) {
    if (_isLocal) {
      final local = local_image.localFileImage(
        imageUrl,
        fit: fit,
        errorBuilder: _errorWidget,
      );
      if (local != null) return local;
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      imageRenderMethodForWeb: appWebImageRenderMethod,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      placeholder: placeholder,
      errorWidget: (context, url, error) => _errorWidget(context),
    );
  }

  Widget _errorWidget(BuildContext context) =>
      errorBuilder?.call(context) ?? const Icon(Icons.image, size: 64);
}