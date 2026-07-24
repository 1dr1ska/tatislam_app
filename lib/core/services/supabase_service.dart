import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to provide Supabase client
class SupabaseService {
  static SupabaseClient get client {
    return Supabase.instance.client;
  }
}
