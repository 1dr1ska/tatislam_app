import 'dart:typed_data';

/// Результат оптимизации изображения.
///
/// Содержит обработанные или исходные байты, размеры до/после
/// и флаг, выполнялась ли оптимизация.
class ImageOptimizationResult {
  /// Байты изображения (исходные или оптимизированные).
  final Uint8List bytes;

  /// Имя файла (может отличаться от исходного, если расширение
  /// изменилось, например `.png` → `.jpg`).
  final String fileName;

  /// Размер исходного файла в байтах.
  final int originalSize;

  /// Размер после обработки в байтах.
  final int finalSize;

  /// `true`, если оптимизация реально выполнялась
  /// (ресайз и/или пересохранение).
  final bool wasOptimized;

  const ImageOptimizationResult({
    required this.bytes,
    required this.fileName,
    required this.originalSize,
    required this.finalSize,
    required this.wasOptimized,
  });
}