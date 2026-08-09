/// Conditional export barrel — selects the correct platform implementation.
///
/// - **Web:** delegates to [youtube_web_view_factory_web.dart] which registers a
///   real `HtmlElementView` iframe via `dart:ui_web` + `package:web`.
/// - **Non-web:** delegates to [youtube_web_view_factory_stub.dart] which returns
///   `null` (no-op stub).
library;

export 'youtube_web_view_factory_stub.dart'
    if (dart.library.js_interop) 'youtube_web_view_factory_web.dart';