import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Web implementation that registers an HtmlElementView with a native HTML5
/// `<video controls>` element pointing at the uploaded file's public URL.
///
/// Returns the view ID that can be used with [HtmlElementView].
String? registerUploadedVideoView(String url) {
  final viewId = 'uploaded_video_${DateTime.now().millisecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) {
      final video = web.document.createElement('video');
      video.setAttribute('style', 'width:100%;height:100%;background:#000;border:none');
      video.setAttribute('controls', '');
      video.setAttribute('src', url);
      video.setAttribute('playsinline', '');
      return video;
    },
  );

  return viewId;
}