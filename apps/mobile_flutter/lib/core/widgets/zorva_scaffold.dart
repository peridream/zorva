import 'package:flutter/material.dart';
import '../theme/zorva_theme.dart';

/// Reusable Master Layout Wrapper for all 10-20 screens in Zorva.
/// Guarantees 100% visual consistency (ambient gold glow, dark onyx background, 
/// brand header, and floating action button).
class ZorvaScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final bool showHeader;
  final VoidCallback? onBack;

  const ZorvaScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.showHeader = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      body: Stack(
        children: [
          // 1. Golden Radial Ambient Aura Mesh (Consistent Across All 20 Screens)
          Positioned(
            top: -80,
            left: MediaQuery.of(context).size.width * 0.05,
            width: MediaQuery.of(context).size.width * 0.9,
            height: 420,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x40EECC66), Colors.transparent],
                  radius: 0.7,
                ),
              ),
            ),
          ),

          // 2. Main Page Content
          SafeArea(
            child: Column(
              children: [
                if (showHeader) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (onBack != null || Navigator.canPop(context))
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios,
                                    color: ZorvaTheme.primaryGold, size: 18),
                                onPressed: onBack ?? () => Navigator.pop(context),
                              ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      ZorvaTheme.goldGradient.createShader(bounds),
                                  child: Text(
                                    title.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: ZorvaTheme.textMuted,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        if (actions != null) Row(children: actions!),
                      ],
                    ),
                  ),
                  const Divider(color: ZorvaTheme.borderDark, height: 1),
                ],

                // Body content
                Expanded(child: body),
              ],
            ),
          ),

          // 3. Floating Action Button Slot
          if (floatingActionButton != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: floatingActionButton!,
            ),
        ],
      ),
    );
  }
}

/// Reusable Luxury Dark Glass Card for all screens
class ZorvaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const ZorvaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B1914), Color(0xFF0F0E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEECC66), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26EECC66),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Reusable Glowing Metallic Button for all screens
class ZorvaButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool loading;

  const ZorvaButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66EECC66),
            blurRadius: 24,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: loading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF0B3), Color(0xFFE5C158), Color(0xFFC59B27)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(icon, color: Colors.black, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
