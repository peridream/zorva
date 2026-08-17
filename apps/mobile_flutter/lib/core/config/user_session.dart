import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class UserSession {
  static String? userId;
  static String fullName = '';
  static String city = 'Austin';
  static double glickoRating = 1500.0;


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
