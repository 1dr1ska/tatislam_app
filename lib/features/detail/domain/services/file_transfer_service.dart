/// Conditional barrel that selects the platform file transfer service.
///
/// - **Web:** [file_transfer_service_web.dart] — browser-only implementation
///   (no `dart:io`): downloading opens the URL in a new tab; share delegates
///   to the platform share dialog.
/// - **Non-web (Android/iOS/desktop):** [file_transfer_service_io.dart] —
///   real file download to a cache, system "Save as" dialog (SAF on Android /
///   document picker on iOS) and share with a temporary native file.
library;

export 'file_transfer_service_io.dart'
    if (dart.library.js_interop) 'file_transfer_service_web.dart';