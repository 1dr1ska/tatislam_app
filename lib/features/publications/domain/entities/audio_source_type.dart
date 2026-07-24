/// Where an [AudioContentBlock]'s file lives.
///
/// `upload` — stored in Supabase Storage (`blocks/<id>/audio/...`).
/// `external` — a plain external URL, no Storage involved.
enum AudioSourceType {
  upload,
  external;

  String get wireValue => name;

  static AudioSourceType fromWireValue(String value) {
    return AudioSourceType.values.firstWhere(
      (v) => v.wireValue == value,
      orElse: () => AudioSourceType.external,
    );
  }
}
