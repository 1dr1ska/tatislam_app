/// Conditional export barrel — selects the correct platform implementation.
///
/// - **Web:** delegates to [uploaded_video_web_view_factory_web.dart] which
///   registers a real `HtmlElementView` with a native HTML5 `<video>` element.
/// - **Non-web:** delegates to [uploaded_video_web_view_factory_stub.dart] which
///   returns `null` (the widget uses a WebViewController instead).
library;

export 'uploaded_video_web_view_factory_stub.dart'
    if (dart.library.js_interop) 'uploaded_video_web_view_factory_web.dart';