import 'dart:async';

import 'package:flutter/material.dart';

/// Resolves image dimensions from an [ImageProvider] once and caches the
/// result by a caller-provided key (the image URL or storage path).
///
/// Used by [ImageContentWidget] to render photos in their original aspect
/// ratio without layout jumps on subsequent builds or revisits.
class ImageDimensionsService {
  final Map<String, Size> _cache = {};
  final Map<String, Future<Size?>> _inflight = {};

  /// Returns the cached size for [key], if any.
  Size? cached(String key) => _cache[key];

  /// Resolves [provider] dimensions, caching by [key].
  ///
  /// A single in-flight future is shared among concurrent callers that use
  /// the same [key], so the same image is never resolved twice.
  Future<Size?> resolve({
    required String key,
    required ImageProvider provider,
    Duration timeout = const Duration(seconds: 10),
  }) {
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);

    final inFlight = _inflight[key];
    if (inFlight != null) return inFlight;

    final future = _doResolve(provider, timeout)
        .then((size) {
          if (size != null) _cache[key] = size;
          return size;
        })
        .whenComplete(() => _inflight.remove(key));

    _inflight[key] = future;
    return future;
  }

  Future<Size?> _doResolve(ImageProvider provider, Duration timeout) async {
    final completer = Completer<Size?>();
    late final ImageStream stream;
    late final ImageStreamListener listener;

    void cleanup() {
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(
            Size(info.image.width.toDouble(), info.image.height.toDouble()),
          );
        }
        // The decoded image is no longer needed — only its dimensions were.
        info.dispose();
        cleanup();
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) completer.complete(null);
        cleanup();
      },
    );

    stream = provider.resolve(ImageConfiguration.empty);
    stream.addListener(listener);

    // Safety net: never block the UI forever if the image cannot be loaded.
    await Future.any([completer.future, Future<void>.delayed(timeout)]);
    if (!completer.isCompleted) {
      completer.complete(null);
      cleanup();
    }
    return completer.future;
  }
}
