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
}
