import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/user_session.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../onboarding/presentation/screens/sign_up_screen.dart';
import '../../../onboarding/presentation/screens/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  int? _cityRank;

  final _nameController = TextEditingController();
  bool _saving = false;

  String get _userId =>
      widget.userId ??
      Supabase.instance.client.auth.currentUser?.id ??
      UserSession.userId ??
      SupabaseConstants.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;
    try {
      final profileRes = await supabase
          .from('profiles')
          .select()
          .eq('id', _userId)
          .maybeSingle();
      if (profileRes != null) _profile = profileRes;

      try {
        final rankRes = await supabase
            .from('city_rankings')
            .select('rank')
            .eq('user_id', _userId)
            .maybeSingle();
        if (rankRes != null) _cityRank = rankRes['rank'] as int?;
      } catch (_) {}
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  void _showEditSheet() {
    _nameController.text = _profile?['full_name'] ?? '';
    final cities = [
      'Austin', 'New York', 'San Francisco', 'Chicago', 'Dallas',
      'Los Angeles', 'London', 'Miami', 'Seattle', 'Toronto', 'Sydney', 'Paris',
    ];
    String selectedCity = _profile?['city'] ?? cities[0];
    if (!cities.contains(selectedCity)) selectedCity = cities[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Color(0xE614171A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(top: BorderSide(color: ZorvaTheme.primaryGold, width: 1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: ZorvaTheme.borderSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Edit Profile',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ZorvaTheme.textPrimary)),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: ZorvaTheme.textPrimary, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline, color: ZorvaTheme.primaryGold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('City', style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2024),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ZorvaTheme.borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCity,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1C2024),
                            style: const TextStyle(color: ZorvaTheme.textPrimary, fontWeight: FontWeight.bold),
                            items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setSheet(() => selectedCity = v ?? selectedCity),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  setSheet(() => _saving = true);
                                  try {
                                    await Supabase.instance.client
                                        .from('profiles')
                                        .update({
                                          'full_name': _nameController.text.trim(),
                                          'city': selectedCity,
                                        })
                                        .eq('id', _userId);
                                    if (mounted) {
                                      Navigator.pop(ctx);
                                      _loadProfile();
                                    }
                                  } catch (e) {
                                    debugPrint('Update error: $e');
                                  } finally {
                                    if (mounted) setSheet(() => _saving = false);
                                  }
                                },
                          child: _saving
                              ? const CircularProgressIndicator(color: ZorvaTheme.background)
                              : const Text('SAVE CHANGES',
                                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void _showSignOutConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2024),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ZorvaTheme.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 36),
                const SizedBox(height: 16),
                const Text(
                  'SIGN OUT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ZorvaTheme.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to sign out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: ZorvaTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                          (route) => false,
                        );
                      }
                    },
                    child: const Text('YES, SIGN OUT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ZorvaTheme.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('CANCEL',
                        style: TextStyle(color: ZorvaTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (_loading) {
      return const Scaffold(
        backgroundColor: ZorvaTheme.background,
        body: Center(child: CircularProgressIndicator(color: ZorvaTheme.primaryGold)),
      );
    }

    final name = _profile?['full_name'] as String? ?? 'Player';
    final city = _profile?['city'] as String? ?? '—';
    final sport = _profile?['sport'] as String? ?? 'Table Tennis';
    final email = _profile?['email'] as String? ?? '';

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      body: Stack(
        children: [
          // Background aura
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: ZorvaTheme.goldGlowAura,
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              color: ZorvaTheme.primaryGold,
              backgroundColor: const Color(0xFF1C2024),
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('MY PROFILE',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900,
                              letterSpacing: 3, color: ZorvaTheme.primaryGold,
                            )),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: ZorvaTheme.textSecondary, size: 22),
                              onPressed: _showEditSheet,
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, color: ZorvaTheme.textSecondary, size: 22),
                              onPressed: _showSignOutConfirm,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Avatar + Name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD4AF37), Color(0xFFA07830)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4AF37).withOpacity(0.35),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _initials(name),
                                style: const TextStyle(
                                  fontSize: 36, fontWeight: FontWeight.w900,
                                  color: Colors.white, letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(name,
                              style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900,
                                color: ZorvaTheme.textPrimary, letterSpacing: 0.5,
                              )),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              _badge(Icons.location_on_outlined, city),
                              _badge(Icons.sports_tennis, sport),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    const SizedBox(height: 24),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2024),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZorvaTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ZorvaTheme.primaryGold),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(fontSize: 12, color: ZorvaTheme.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {bool highlight = false, bool danger = false}) {
    final color = danger
        ? Colors.redAccent
        : highlight
            ? ZorvaTheme.primaryGold
            : ZorvaTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2024),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: highlight && !danger ? const Color(0x44D4AF37) : ZorvaTheme.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: color, height: 1,
              )),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 10, color: ZorvaTheme.textMuted, letterSpacing: 0.5)),
        ],
      ),
    );
  }

}
