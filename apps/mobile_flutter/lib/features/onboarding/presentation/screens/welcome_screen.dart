import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/zorva_theme.dart';
import 'sign_in_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const String heroImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA7qJNZUJ5pGLjiImXcsGcmlFUKb4bJ-Ud0gi5SLqibtLRop8WPU3v27Cf0g6s1RqJBz22j9s55zHMho1_5HxU1tchIj4MpwzBPuG1zjrrxmDe8FLRhkrMervndZzNgm9uRZB9bHqp_IXTOZhMGOKeaRiTiiTZ6vMlOTh9vxMw6Jj1S4GShIHtc_lJRBBrPAFoGKqJZ9hKMeOlyUpRKw-IIWzltNp6cJ5ZYXWdkYjgIxpUeuP_OZ5gq64hfvYHX3iMgb5bvNBpTk3A';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      body: Stack(
        children: [
          // Ambient Liquid Radial Gold Glow Orbs in Background
          Positioned(
            top: -60,
            left: size.width * 0.15,
            width: size.width * 0.7,
            height: 320,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: ZorvaTheme.goldGlowAura,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -30,
            width: size.width * 0.5,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x1AD4AF37),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Header (Logo & Specular Badge)
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFE0C068), Color(0xFFD4AF37)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'ZORVA',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Glassmorphic Badge with Blur
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0x22323539),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0x66D4AF37), width: 1.2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1AD4AF37),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Text(
                              'SPORTS IDENTITY',
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
                    ],
                  ),

                  // 2. Main Hero Graphic & Copy
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hero Image from local assets (with network fallback)
                        SizedBox(
                          height: 200,
                          child: Image.asset(
                            'assets/images/hero_passport.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.network(
                                heroImageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0x1AD4AF37),
                                      border: Border.all(color: ZorvaTheme.primaryGold, width: 2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33D4AF37),
                                          blurRadius: 24,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.sports_tennis,
                                      size: 64,
                                      color: ZorvaTheme.primaryGold,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Make Every Game Count.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: ZorvaTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'A new way to play. Build your lifelong sports passport, log matches in 15 seconds, and track your true rating.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: ZorvaTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Glassmorphic Feature Chips Row
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _StitchChip(icon: Icons.bolt, label: 'Sub-15s Logger'),
                            _StitchChip(icon: Icons.bar_chart, label: 'Dual Glicko-2'),
                            _StitchChip(icon: Icons.public, label: 'Sports Passport'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 3. Bottom Action Section
                  Column(
                    children: [
                      // Liquid Solid Gold Button with Glow
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44D4AF37),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignInScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZorvaTheme.primaryGold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                "LET'S JUMP IN 🚀",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: ZorvaTheme.background,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Ultra-Modern Real-time Glassmorphic Chip Widget
class _StitchChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StitchChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x221C2024),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x44D4AF37), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11D4AF37),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: ZorvaTheme.primaryGold),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ZorvaTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
