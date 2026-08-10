import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConstants {
  static const String supabaseUrl = "https://mdegfrekmcgejyvekodn.supabase.co";
  static const String supabaseAnonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kZWdmcmVrbWNnZWp5dmVrb2RuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2MjkxODAsImV4cCI6MjEwMTIwNTE4MH0.hFoCT73-fC3-8ISF0aHKy8JSiar5-hy1ZmLlq50vTtA";

  /// Gets current authenticated Supabase Auth User ID or fallback
  static String get currentUserId {
    final authId = Supabase.instance.client.auth.currentUser?.id;
    if (authId != null && authId.isNotEmpty) {
      return authId;
    }
    return "612f804e-b1b5-4ccb-9297-aba87ea5a889"; // Default test ID if unauthenticated
  }
}
