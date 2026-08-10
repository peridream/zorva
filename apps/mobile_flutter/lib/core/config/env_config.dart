import '../constants/supabase_constants.dart';

enum Environment { dev, staging, prod }

class EnvConfig {
  static Environment _environment = Environment.dev;

  static void initialize({Environment env = Environment.dev}) {
    _environment = env;
  }

  static Environment get current => _environment;
  static bool get isDev => _environment == Environment.dev;
  static bool get isStaging => _environment == Environment.staging;
  static bool get isProd => _environment == Environment.prod;

  static String get environmentName {
    switch (_environment) {
      case Environment.dev:
        return 'DEV';
      case Environment.staging:
        return 'STAGING';
      case Environment.prod:
        return 'PROD';
    }
  }

  static String get supabaseUrl {
    switch (_environment) {
      case Environment.dev:
        return SupabaseConstants.supabaseUrl;
      case Environment.staging:
        return 'https://staging-zorva.supabase.co';
      case Environment.prod:
        return 'https://prod-zorva.supabase.co';
    }
  }

  static String get supabaseAnonKey {
    switch (_environment) {
      case Environment.dev:
        return SupabaseConstants.supabaseAnonKey;
      case Environment.staging:
        return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.staging-key';
      case Environment.prod:
        return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.prod-key';
    }
  }
}
