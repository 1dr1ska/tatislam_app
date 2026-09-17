/// Payload of a push notification about a new publication.
///
/// FCM `data` messages deliver every value as a string, so the parser converts
/// explicitly and never throws on missing keys.
///
/// Mirrors the keys sent by the `notify-new-publication` Edge Function:
/// `type`, `publication_id`, `publication_type`, `publication_title`.
class PushPayload {
  final String? publicationId;
  final String? publicationType;
  final String? publicationTitle;

  /// Storage path of the single photo backing a `photo` publication
  /// (`data['publication_photo_path']`). Used to open the fullscreen photo
  /// viewer on push tap — photo publications have no content blocks.
  final String? publicationPhotoPath;

  const PushPayload({
    this.publicationId,
    this.publicationType,
    this.publicationTitle,
    this.publicationPhotoPath,
  });

  /// Builds a payload from the FCM `data` map, tolerating missing fields.
  ///
  /// Returns `null` when the message is not about a new publication
  /// (i.e. `data['type'] != 'new_publication'`).
  factory PushPayload.fromData(Map<String, dynamic> data) {
    if (data['type'] != 'new_publication') return const PushPayload();
    return PushPayload(
      publicationId: _stringOrNull(data['publication_id']),
      publicationType: _stringOrNull(data['publication_type']),
      publicationTitle: _stringOrNull(data['publication_title']),
      publicationPhotoPath: _stringOrNull(data['publication_photo_path']),
    );
  }

  static String? _stringOrNull(Object? value) =>
      (value is String && value.isNotEmpty) ? value : null;
}