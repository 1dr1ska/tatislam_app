/// Where a [VideoContentBlock]'s file lives.
///
/// `upload` — stored in Storage (`videos/<uuid>.<ext>`), resolved via
///            [MediaStorageRepository.publicUrlFor].
/// `external` — a plain URL (youtube/rutube/vk/direct), no Storage involved.
enum VideoSourceType {
  upload,
  external;

  String get wireValue => name;

  static VideoSourceType fromWireValue(String value) {
    return VideoSourceType.values.firstWhere(
      (v) => v.wireValue == value,
      orElse: () => VideoSourceType.external,
    );
  }
}