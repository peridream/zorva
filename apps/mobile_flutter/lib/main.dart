import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env_config.dart';
import 'core/theme/zorva_theme.dart';
import 'features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'features/onboarding/presentation/screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Environment (Default to Dev)
  EnvConfig.initialize(env: Environment.dev);

  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization warning (${EnvConfig.environmentName}): $e');
  }

  runApp(const ZorvaApp());
}


class ZorvaApp extends StatelessWidget {
  const ZorvaApp({super.key});

  @override
  Widget build(BuildContext context) {
    bool hasSession = false;
    try {
      hasSession = Supabase.instance.client.auth.currentSession != null;
    } catch (_) {}

    return MaterialApp(
      title: 'Zorva – Build Your Sports Identity',
      debugShowCheckedModeBanner: false,
      theme: ZorvaTheme.darkTheme,
      scrollBehavior: AppScrollBehavior(),
      home: hasSession ? const HomeDashboardScreen() : const WelcomeScreen(),
    );
  }
}


