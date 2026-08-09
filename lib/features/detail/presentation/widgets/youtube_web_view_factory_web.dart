import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Web implementation that registers an HtmlElementView with a YouTube iframe.
///
/// Returns the view ID that can be used with [HtmlElementView].
/// Registration happens once — subsequent calls with the same [videoId] return
/// the previously registered view ID.
String? registerYoutubeView(String videoId) {
  final viewId =
      'youtube_${videoId}_${DateTime.now().millisecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final htmlIFrame = web.document.createElement('iframe')
          as web.HTMLIFrameElement;
      htmlIFrame.src = 'https://www.youtube.com/embed/$videoId';
      htmlIFrame.style.width = '100%';
      htmlIFrame.style.height = '100%';
      htmlIFrame.style.border = 'none';
      htmlIFrame.allow = 'autoplay; encrypted-media; picture-in-picture';
      htmlIFrame.allowFullscreen = true;
      return htmlIFrame;
    },
  );

  return viewId;
}