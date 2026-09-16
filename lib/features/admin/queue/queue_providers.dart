import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tatislam_app/features/admin/queue/publication_upload_queue.dart';

export 'queue_state_providers.dart';

/// The single background publication upload queue for the whole application.
///
/// Exposed through a module-level singleton: the queue must keep running (and
/// keep its state) even if Riverpod re-evaluates or disposes the provider
/// element while the admin is away from the admin screens.
PublicationUploadQueue? _publicationUploadQueueSingleton;

final publicationUploadQueueProvider = Provider<PublicationUploadQueue>((ref) {
  _publicationUploadQueueSingleton ??= PublicationUploadQueue(ref);
  return _publicationUploadQueueSingleton!;
});
