/// Resolves a storage path to a local `file://` URI when an offline copy of
/// the resource is available.
///
/// Returns `null` to signal "no local copy" — the caller then falls back to
/// the network URL (via [MediaStorageRepository.publicUrlFor]).
typedef LocalMediaResolver = String? Function(String storagePath);