import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Default local backend URL (overridable per environment)
  static String baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  // --- APP SETTINGS STATE & GETTERS ---
  static final Map<String, String> _settingsCache = {
    'monetization_enabled': 'false',
    'growth_phase_duration_days': '365',
    'founder_cap_per_city': '20',
    'flagship_annual_price_usd': '9.99',
    'group_one_time_fee_usd': '4.99',
    'announcement_banner_enabled': 'false',
    'announcement_banner_text': '',
  };

  static Future<Map<String, String>> fetchSettings() async {
    try {
      final url = Uri.parse('$baseUrl/settings');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            _settingsCache[k.toString()] = v.toString();
          });
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService fetchSettings error: $e');
    }
    return _settingsCache;
  }

  static bool get isMonetizationEnabled =>
      (_settingsCache['monetization_enabled'] ?? 'false').toLowerCase() == 'true';

  static bool get isAnnouncementBannerEnabled =>
      (_settingsCache['announcement_banner_enabled'] ?? 'false').toLowerCase() == 'true';

  static String get announcementBannerText =>
      _settingsCache['announcement_banner_text'] ?? '';

  static String get flagshipAnnualPrice =>
      _settingsCache['flagship_annual_price_usd'] ?? '9.99';

  static String get groupOneTimeFee =>
      _settingsCache['group_one_time_fee_usd'] ?? '4.99';

  static int get founderCapPerCity =>
      int.tryParse(_settingsCache['founder_cap_per_city'] ?? '20') ?? 20;

  // --- USERS & ONBOARDING API ---
  static Future<Map<String, dynamic>?> registerUser({
    required String userId,
    String? email,
    required String username,
    required String fullName,
    required String city,
    String sport = 'Table Tennis',
    double selfRating = 1200.0,
    int experienceYears = 1,
    String playFrequency = '1-2 times/week',
    String playStyle = 'All-Round',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'email': email,
          'username': username,
          'full_name': fullName,
          'city': city,
          'sport': sport,
          'self_rating': selfRating,
          'experience_years': experienceYears,
          'play_frequency': playFrequency,
          'play_style': playStyle,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        return {'error': err['detail'] ?? 'Registration failed'};
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService registerUser error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getOpponents({
    String? city,
    String? search,
    String? excludeUserId,
    int limit = 20,
  }) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (excludeUserId != null && excludeUserId.isNotEmpty) params['exclude_user_id'] = excludeUserId;

      final uri = Uri.parse('$baseUrl/users/opponents').replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getOpponents error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/users/profile/$userId')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getUserProfile error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/users/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService updateUserProfile error: $e');
    }
    return null;
  }

  // --- SUBSCRIPTIONS API ---
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

  // --- RATINGS API ---
  static Future<List<Map<String, dynamic>>> getUserRatings(String userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/ratings/user/$userId')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getUserRatings fallback to Supabase: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> checkDuplicateUser(String fullName, String city) async {
    try {
      final uri = Uri.parse('$baseUrl/users/check-duplicate?full_name=${Uri.encodeComponent(fullName)}&city=${Uri.encodeComponent(city)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService checkDuplicateUser error: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> lookupUser(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/users/lookup?query=${Uri.encodeComponent(query)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService lookupUser error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getUserDashboard(String userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/users/dashboard/$userId')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getUserDashboard error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getRatingContexts() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/ratings/contexts')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getRatingContexts error: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getLeaderboard(String contextId, {int limit = 50}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/ratings/leaderboard/$contextId?limit=$limit')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService getLeaderboard error: $e');
    }
    return [];
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

  // --- MATCHES API ---
  static Future<Map<String, dynamic>?> recordMatch({
    required int sportId,
    required String player1Id,
    required String player2Id,
    required String winnerId,
    required Map<String, dynamic> scoreJson,
    required String recordedBy,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/matches'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sport_id': sportId,
          'player1_id': player1Id,
          'player2_id': player2Id,
          'winner_id': winnerId,
          'score_json': scoreJson,
          'recorded_by': recordedBy,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        return {'error': err['detail'] ?? 'Failed to record match'};
      }
    } catch (e) {
      debugPrint('ℹ️ ApiService recordMatch error: $e');
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
