import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class UserSession {
  static String? userId;
  static String fullName = '';
  static String city = 'Austin';
  static double glickoRating = 1500.0;

  /// Asynchronously queries Supabase profiles for existing players in a city and returns exact row count
  static Future<int> registerAndGetNextRank(String cityInput) async {
    final cleanCity = cityInput.trim();
    int currentCount = 0;

    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('profiles')
          .select('id')
          .ilike('city', cleanCity);
      currentCount = res.length;
      debugPrint('Exact Supabase profiles count for "$cleanCity": $currentCount');
    } catch (dbErr) {
      debugPrint('DB city count query note: $dbErr');
    }

    return currentCount;
  }

  static String getOrdinal(int n) {
    final val = n <= 0 ? 1 : n;
    if (val >= 11 && val <= 13) return '${val}th';
    switch (val % 10) {
      case 1:
        return '${val}st';
      case 2:
        return '${val}nd';
      case 3:
        return '${val}rd';
      default:
        return '${val}th';
    }
  }
}
