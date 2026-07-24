/// Centralized names of Supabase tables and the Storage bucket.
///
/// Keeping these in one place avoids typos scattered across data sources and
/// makes renames a one-line change.
class SupabaseTables {
  SupabaseTables._();

  static const String profiles = 'profiles';
  static const String sections = 'sections';
  static const String publications = 'publications';
  static const String contentBlocks = 'content_blocks';
  static const String publicationSections = 'publication_sections';
}

class SupabaseBuckets {
  SupabaseBuckets._();

  static const String media = 'media';
}
