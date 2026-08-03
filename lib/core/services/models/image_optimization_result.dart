import 'dart:typed_data';

/// Result of a single image optimization attempt.
class ImageOptimizationResult {
  /// The final bytes — either optimized or original.
  final Uint8List bytes;

  /// The final file name (may differ if extension was changed to .jpg).
  final String fileName;

  /// Size of the original image in bytes.
  final int originalSize;

  /// Size of the final image in bytes.
  final int finalSize;

  /// Whether any optimization was actually applied.
  final bool wasOptimized;

  const ImageOptimizationResult({
    required this.bytes,
    required this.fileName,
    required this.originalSize,
    required this.finalSize,
    required this.wasOptimized,
  });

  /// Percentage of space saved (0-100). Returns 0 if nothing was saved.
  double get savingsPercent {
    if (originalSize == 0) return 0;
    return ((originalSize - finalSize) / originalSize * 100).clamp(0, 100);
  }
}