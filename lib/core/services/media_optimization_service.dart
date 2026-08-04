import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'models/image_optimization_result.dart';

/// Сервис для автоматической оптимизации изображений перед загрузкой.
///
/// ## Логика оптимизации
///
/// 1. Декодирует изображение.
/// 2. Проверяет наличие альфа-канала. Если есть прозрачность —
///    изображение не конвертируется в JPEG, возвращается исходный файл.
/// 3. Если максимальная сторона > 1920 px — пропорционально уменьшает
///    до 1920 px и сохраняет как JPEG с качеством 90.
/// 4. Если после обработки размер оказался больше исходного —
///    возвращается исходный файл.
/// 5. Если максимальная сторона ≤ 1920 px — возвращается исходный файл
///    без изменений.
///
/// API сервиса не зависит от `dart:io` — работает с `Uint8List`.
class MediaOptimizationService {
  static const int _maxDimension = 1920;
  static const int _jpegQuality = 90;

  const MediaOptimizationService();

  /// Оптимизирует изображение, переданное как [originalBytes].
  ///
  /// [originalFileName] — исходное имя файла (нужно для определения
  /// расширения и формирования итогового имени).
  ///
  /// Возвращает [ImageOptimizationResult] с обработанными (или исходными)
  /// байтами.
  Future<ImageOptimizationResult> optimizeImage({
    required Uint8List originalBytes,
    required String originalFileName,
  }) async {
    final originalSize = originalBytes.length;

    // 1. Декодируем изображение
    final image = img.decodeImage(originalBytes);

    // Если не удалось декодировать — возвращаем исходные данные как есть
    if (image == null) {
      return ImageOptimizationResult(
        bytes: originalBytes,
        fileName: originalFileName,
        originalSize: originalSize,
        finalSize: originalSize,
        wasOptimized: false,
      );
    }

    // 2. Проверяем наличие альфа-канала (прозрачность)
    final hasAlpha = image.hasAlpha;

    // 3. Проверяем, нужно ли ресайзить
    final maxSide = max(image.width, image.height);

    if (maxSide <= _maxDimension || hasAlpha) {
      // Если изображение уже достаточно маленькое или имеет прозрачность —
      // возвращаем исходные байты без изменений
      return ImageOptimizationResult(
        bytes: originalBytes,
        fileName: originalFileName,
        originalSize: originalSize,
        finalSize: originalSize,
        wasOptimized: false,
      );
    }

    // 4. Пропорционально уменьшаем до 1920 px
    final scale = _maxDimension / maxSide;
    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();

    final resized = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic,
    );

    // 5. Сохраняем как JPEG с качеством 90
    final optimizedBytes = img.encodeJpg(resized, quality: _jpegQuality);

    // 6. Если после обработки размер стал больше — возвращаем исходный
    if (optimizedBytes.length > originalSize) {
      return ImageOptimizationResult(
        bytes: originalBytes,
        fileName: originalFileName,
        originalSize: originalSize,
        finalSize: originalSize,
        wasOptimized: true,
      );
    }

    // 7. Меняем расширение на .jpg, если было другим
    final baseName = _stripExtension(originalFileName);
    final jpgFileName = '$baseName.jpg';

    return ImageOptimizationResult(
      bytes: optimizedBytes,
      fileName: jpgFileName,
      originalSize: originalSize,
      finalSize: optimizedBytes.length,
      wasOptimized: true,
    );
  }

  /// Удаляет расширение файла из имени.
  String _stripExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0) {
      return fileName.substring(0, dotIndex);
    }
    return fileName;
  }
}
