import 'dart:io';

import 'package:flutter/material.dart';

/// Native (Android / iOS / desktop) implementation: renders a `file://` URI
/// straight from disk.
///
/// A downloaded offline copy resolves its images to local `file://` URIs, and
/// `CachedNetworkImage` cannot load those — only a real file can.
Widget? localFileImage(
  String imageUrl, {
  required BoxFit fit,
  required Widget Function(BuildContext) errorBuilder,
}) {
  return Image.file(
    File.fromUri(Uri.parse(imageUrl)),
    fit: fit,
    gaplessPlayback: true,
    errorBuilder: (context, error, stackTrace) => errorBuilder(context),
  );
}

/// Image provider for a local `file://` URI (used to resolve image dimensions),
/// or null when the URI cannot be turned into a file.
ImageProvider? localFileImageProvider(String imageUrl) =>
    FileImage(File.fromUri(Uri.parse(imageUrl)));