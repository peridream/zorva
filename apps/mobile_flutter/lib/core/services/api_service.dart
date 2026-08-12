import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  // Default local backend URL (overridable per environment)
  static String baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  static Future<Map<String, dynamic>?> getSubscription(String userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/subscriptions/$userId')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getSubscription fallback to Supabase: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPlayerInsights(String userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/insights/$userId')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getPlayerInsights fallback to Supabase: $e');
    }
    return null;
  }

  static Future<bool> confirmMatch(String matchId, String userId, {String action = 'confirmed'}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/matches/$matchId/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'action': action}),
      ).timeout(const Duration(seconds: 4));
      
      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService confirmMatch fallback to Supabase: $e');
    }
    return false;
  }

  // --- GROUPS API ---

  static Future<Map<String, dynamic>?> createGroup({
    required String name,
    required String creatorId,
    String description = '',
    String city = 'Dallas',
    String sport = 'Table Tennis',
    String groupType = 'community',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/groups/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'description': description,
          'city': city,
          'sport': sport,
          'group_type': groupType,
          'creator_id': creatorId,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        return {'error': err['detail'] ?? 'Failed to create group'};
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService createGroup error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> joinGroup({
    required String userId,
    required String inviteCode,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/groups/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'invite_code': inviteCode,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        return {'error': err['detail'] ?? 'Failed to join group'};
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService joinGroup error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/groups/user/$userId')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['groups'] != null) {
          return List<Map<String, dynamic>>.from(data['groups']);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getUserGroups error: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getGroupLeaderboard(String groupId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/groups/$groupId/leaderboard')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['leaderboard'] != null) {
          return List<Map<String, dynamic>>.from(data['leaderboard']);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getGroupLeaderboard error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getGroupInsights(String groupId, String userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/groups/$groupId/insights/$userId')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getGroupInsights error: $e');
    }
    return null;
  }
}
