import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Web implementation that registers an HtmlElementView with a RuTube iframe.
///
/// Returns the view ID that can be used with [HtmlElementView].
String? registerRutubeView(String videoId) {
  final viewId =
      'rutube_${videoId}_${DateTime.now().millisecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final htmlIFrame = web.document.createElement('iframe')
          as web.HTMLIFrameElement;
      htmlIFrame.src = 'https://rutube.ru/play/embed/$videoId';
      htmlIFrame.style.width = '100%';
      htmlIFrame.style.height = '100%';
      htmlIFrame.style.border = 'none';
      htmlIFrame.allow = 'autoplay; encrypted-media';
      htmlIFrame.allowFullscreen = true;
      return htmlIFrame;
    },
  );

  return viewId;
}