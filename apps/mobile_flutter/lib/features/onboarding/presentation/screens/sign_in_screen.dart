import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../dashboard/presentation/screens/home_dashboard_screen.dart';
import 'city_onboarding_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emailOtpController = TextEditingController();

  bool _loading = false;
  bool _emailOtpSent = false;
  String? _errorMessage;
  Timer? _errorTimer;

  void _clearError() {
    if (_errorMessage != null) {
      _errorTimer?.cancel();
      setState(() => _errorMessage = null);
    }
  }

  void _showThemeError(String message) {
    if (!mounted) return;
    _errorTimer?.cancel();
    setState(() => _errorMessage = message);
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _emailController.dispose();
    _emailOtpController.dispose();
    super.dispose();
  }

  // Email OTP
  Future<void> _sendEmailOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showThemeError('Please enter a valid email address.');
      return;
    }

    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      await supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
      setState(() => _emailOtpSent = true);
    } catch (e) {
      debugPrint('Email OTP note: $e');
      await _proceedWithSmartRouting(email);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    final email = _emailController.text.trim();
    final token = _emailOtpController.text.trim();

    if (token.length < 6) {
      _showThemeError('Please enter the 6-digit verification code.');
      return;
    }

    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      final res = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );
      await _proceedWithSmartRouting(res.user?.email ?? email);
    } catch (e) {
      await _proceedWithSmartRouting(email);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.zorva://login-callback/',
      );
    } catch (e) {
      await _proceedWithSmartRouting(supabase.auth.currentUser?.email ?? '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;
    try {
      await supabase.auth.signInWithOAuth(OAuthProvider.apple);
    } catch (e) {
      await _proceedWithSmartRouting(supabase.auth.currentUser?.email ?? '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _proceedWithSmartRouting(String email) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId == null) {
      _showThemeError('Sign in failed. Please try again.');
      return;
    }

    if (!mounted) return;

    // 🔍 Smart Routing: Check if profile is COMPLETE (name + city required)
    try {
      final profileRes = await supabase
          .from('profiles')
          .select('id, full_name, city')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      final hasCompletedOnboarding =
          profileRes != null &&
          (profileRes['full_name'] as String? ?? '').trim().isNotEmpty &&
          (profileRes['city'] as String? ?? '').trim().isNotEmpty;

      if (hasCompletedOnboarding) {
        // ✅ Returning player with complete profile — go to Dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeDashboardScreen(
              userId: userId,
              displayName: profileRes!['full_name'] as String?,
              city: profileRes['city'] as String?,
            ),
          ),
          (route) => false,
        );
      } else {
        // 🆕 New or incomplete profile — go to City Onboarding
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CityOnboardingScreen(
              authUserId: userId,
              email: email,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Profile lookup note: $e');
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CityOnboardingScreen(
            authUserId: userId,
            email: email,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      appBar: AppBar(
        backgroundColor: ZorvaTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: ZorvaTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ZORVA',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: ZorvaTheme.textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gold Aura Orbs
          Positioned(
            top: -80,
            left: size.width * 0.1,
            width: size.width * 0.8,
            height: 350,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: ZorvaTheme.goldGlowAura,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -20,
            width: size.width * 0.5,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1AD4AF37), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Specular Badge
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x33323539),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ZorvaTheme.primaryGold, width: 1),
                        ),
                        child: const Text(
                          'WELCOME BACK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: ZorvaTheme.primaryGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Welcome Back to Zorva',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ZorvaTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to access your lifelong sports passport, Glicko-2 ratings, and city leaderboards.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: ZorvaTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Real-time BackdropFilter Glassmorphic Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0x331C2024),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x44D4AF37), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1AD4AF37),
                              blurRadius: 24,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_emailOtpSent) ...[
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                onTap: _clearError,
                                onChanged: (_) => _clearError(),
                                style: const TextStyle(color: ZorvaTheme.textPrimary, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'alex@example.com',
                                  prefixIcon: Icon(Icons.alternate_email, color: ZorvaTheme.primaryGold),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _sendEmailOtp,
                                  child: _loading
                                      ? const CircularProgressIndicator(color: ZorvaTheme.background)
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'SIGN IN WITH EMAIL',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(Icons.arrow_forward, size: 18),
                                          ],
                                        ),
                                ),
                              ),
                            ] else ...[
                              TextField(
                                controller: _emailOtpController,
                                keyboardType: TextInputType.number,
                                onTap: _clearError,
                                onChanged: (_) => _clearError(),
                                style: const TextStyle(
                                  color: ZorvaTheme.textPrimary,
                                  fontSize: 22,
                                  letterSpacing: 6,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  labelText: 'Email Verification Code',
                                  hintText: '123456',
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _verifyEmailOtp,
                                  child: _loading
                                      ? const CircularProgressIndicator(color: ZorvaTheme.background)
                                      : const Text(
                                          'VERIFY & SIGN IN ⚡',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Social Auth Options
                  Row(
                    children: const [
                      Expanded(child: Divider(color: ZorvaTheme.borderSubtle)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR 1-TAP SOCIAL SIGN IN',
                          style: TextStyle(
                            color: ZorvaTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: ZorvaTheme.borderSubtle)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: ZorvaTheme.surfaceContainer,
                            side: const BorderSide(color: ZorvaTheme.borderSubtle),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _loading ? null : _handleGoogleSignIn,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🌐 ', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 6),
                              Text(
                                'Google',
                                style: TextStyle(
                                  color: ZorvaTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: ZorvaTheme.surfaceContainer,
                            side: const BorderSide(color: ZorvaTheme.borderSubtle),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _loading ? null : _handleAppleSignIn,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🍎 ', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 6),
                              Text(
                                'Apple',
                                style: TextStyle(
                                  color: ZorvaTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Footer Navigation Link to Sign Up
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text.rich(
                      TextSpan(
                        text: 'New player? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: ZorvaTheme.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Create Passport Account',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              color: ZorvaTheme.primaryGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ERROR BANNER
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ZorvaTheme.primaryGold, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33D4AF37),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: ZorvaTheme.primaryGold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ZorvaTheme.primaryGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
