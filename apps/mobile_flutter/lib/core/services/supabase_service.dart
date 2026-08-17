import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service layer for all direct Supabase reads, profile writes, and Realtime streams.
///
/// Complex rating math (Glicko-2), match confirmations, and deep analytics
/// route through [ApiService].
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ==========================================
  // 1. PROFILES & USER LOOKUPS
  // ==========================================

  /// Fetch a player's profile by user ID.
  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final res = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.getProfile error: $e');
      return null;
    }
  }

  /// Update a player's profile attributes.
  static Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      final data = Map<String, dynamic>.from(updates);
      data['updated_at'] = DateTime.now().toIso8601String();
      await client.from('profiles').update(data).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.updateProfile error: $e');
      return false;
    }
  }

  /// Check if a profile with the same name and city already exists (Smart Duplicate Check).
  static Future<List<Map<String, dynamic>>> checkDuplicateUser(String fullName, String city) async {
    try {
      final res = await client
          .from('profiles')
          .select('id, full_name, city, email, phone')
          .ilike('full_name', fullName.trim())
          .ilike('city', city.trim());
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.checkDuplicateUser error: $e');
      return [];
    }
  }

  /// Lookup user by email, phone, or username for sign in verification.
  static Future<List<Map<String, dynamic>>> lookupUser(String query) async {
    final cleanQ = query.trim();
    try {
      final res = await client
          .from('profiles')
          .select('*')
          .or('email.eq.$cleanQ,phone.eq.$cleanQ,username.eq.$cleanQ');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.lookupUser error: $e');
      return [];
    }
  }

  /// Search opponents by city with optional search query.
  static Future<List<Map<String, dynamic>>> searchOpponents({
    String? city,
    String? search,
    String? excludeUserId,
    int limit = 20,
  }) async {
    try {
      var query = client
          .from('profiles')
          .select('id, username, full_name, city, is_founder, avatar_url');

      if (city != null && city.trim().isNotEmpty) {
        query = query.eq('city', city.trim());
      }
      if (excludeUserId != null && excludeUserId.isNotEmpty) {
        query = query.neq('id', excludeUserId);
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('full_name', '%${search.trim()}%');
      }

      final res = await query.limit(limit);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.searchOpponents error: $e');
      return [];
    }
  }

  // ==========================================
  // 2. RATINGS & LEADERBOARDS
  // ==========================================

  /// Fetch rating contexts (Flagship, Community, Age Tiers, etc.).
  static Future<List<Map<String, dynamic>>> getRatingContexts() async {
    try {
      final res = await client.from('rating_contexts').select();
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.getRatingContexts error: $e');
      return [];
    }
  }

  /// Fetch user ratings across active rating contexts.
  static Future<List<Map<String, dynamic>>> getUserRatings(String userId) async {
    try {
      final res = await client
          .from('player_context_ratings')
          .select('*, rating_contexts(id, name, type)')
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.getUserRatings error: $e');
      return [];
    }
  }

  /// Fetch leaderboard ranking for a given rating context.
  static Future<List<Map<String, dynamic>>> getLeaderboard(String contextId, {int limit = 50}) async {
    try {
      final res = await client
          .from('player_context_ratings')
          .select('*, profiles!user_id(id, username, full_name, city, is_founder, avatar_url)')
          .eq('context_id', contextId)
          .order('rating', ascending: false)
          .limit(limit);

      final List<Map<String, dynamic>> list = [];
      for (int i = 0; i < (res as List).length; i++) {
        final row = Map<String, dynamic>.from(res[i]);
        row['rank'] = i + 1;
        list.add(row);
      }
      return list;
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.getLeaderboard error: $e');
      return [];
    }
  }

  // ==========================================
  // 3. MATCHES & REALTIME STREAMS
  // ==========================================

  /// Fetch user's verified recent matches.
  static Future<List<Map<String, dynamic>>> getRecentVerifiedMatches(String userId, {int limit = 10}) async {
    try {
      final res = await client
          .from('matches')
          .select('*, creator:creator_id(id, full_name, username, city, avatar_url), opponent:opponent_id(id, full_name, username, city, avatar_url)')
          .or('creator_id.eq.$userId,opponent_id.eq.$userId')
          .eq('status', 'confirmed')
          .order('logged_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.getRecentVerifiedMatches error: $e');
      return [];
    }
  }

  /// Fetch pending matches requiring user approval or pending opponent approval.
  static Future<List<Map<String, dynamic>>> getPendingMatches(String userId) async {
    try {
      final res = await client
          .from('matches')
          .select('*, creator:creator_id(id, full_name, username, city, avatar_url), opponent:opponent_id(id, full_name, username, city, avatar_url)')
          .or('creator_id.eq.$userId,opponent_id.eq.$userId')
          .eq('status', 'pending')
          .order('logged_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ℹ️ SupabaseService.getPendingMatches error: $e');
      return [];
    }
  }

  /// Stream incoming pending match requests in real-time.
  static Stream<List<Map<String, dynamic>>> streamIncomingPendingMatches(String userId) {
    return client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('opponent_id', userId)
        .map((list) => list.where((m) => m['status'] == 'pending').toList());
  }
}
