import 'package:flutter_riverpod/legacy.dart' as legacy;

/// Version counter bumped every time the background publication upload queue
/// changes (job enqueued, progress updated, completed, failed, retried,
/// canceled or finished items cleared). Screens listen/watch it to re-render.
final publicationUploadQueueVersionProvider = legacy.StateProvider<int>(
  (ref) => 0,
);
