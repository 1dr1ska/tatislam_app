import 'package:flutter/material.dart';

/// Web has no real filesystem and offline saving is disabled, so `file://`
/// URIs never occur. Return null so the caller falls back to a network image.
Widget? localFileImage(
  String imageUrl, {
  required BoxFit fit,
  required Widget Function(BuildContext) errorBuilder,
}) =>
    null;

/// No local files on the web — dimensions are always resolved from the network.
ImageProvider? localFileImageProvider(String imageUrl) => null;