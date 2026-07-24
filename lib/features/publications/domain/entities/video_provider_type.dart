/// External video providers supported by [VideoContentBlock].
///
/// Mirrors the `data->>'provider'` values allowed by the `content_blocks`
/// table CHECK constraint (see migration 0006).
enum VideoProviderType {
  youtube,
  rutube,
  vk,
  direct;

  String get wireValue => name;

  static VideoProviderType fromWireValue(String value) {
    return VideoProviderType.values.firstWhere(
      (v) => v.wireValue == value,
      orElse: () => VideoProviderType.direct,
    );
  }
}
