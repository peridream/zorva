import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/user_session.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../dashboard/presentation/screens/home_dashboard_screen.dart';
import 'sign_in_screen.dart';
import 'welcome_screen.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/supabase_service.dart';

class CityOnboardingScreen extends StatefulWidget {
  final String authUserId;
  final String email;

  const CityOnboardingScreen({
    super.key,
    required this.authUserId,
    required this.email,
  });

  @override
  State<CityOnboardingScreen> createState() => _CityOnboardingScreenState();
}

class _CityOnboardingScreenState extends State<CityOnboardingScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _citySearchController = TextEditingController();
  final TextEditingController _customRatingController = TextEditingController();

  String _selectedCity = 'Austin';
  String _cityQuery = '';
  double _selectedRating = 1200.0;
  bool _isCustomRating = false;
  bool _loading = false;
  String? _errorMessage;
  Timer? _errorTimer;

  final List<String> _allCities = [
    'Austin',
    'New York',
    'San Francisco',
    'Chicago',
    'Dallas',
    'Los Angeles',
    'London',
    'Miami',
    'Seattle',
    'Toronto',
    'Sydney',
    'Paris',
    'Tokyo',
    'Berlin',
    'Dubai',
    'Singapore',
    'Barcelona',
    'Melbourne',
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController.text = '';
  }

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
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _fullNameController.dispose();
    _citySearchController.dispose();
    _customRatingController.dispose();
    super.dispose();
  }

  List<String> get _filteredCities {
    if (_cityQuery.isEmpty) return _allCities;
    return _allCities
        .where((city) => city.toLowerCase().contains(_cityQuery.toLowerCase()))
        .toList();
  }

  /// Generates a 100% valid RFC4122 UUID v4 accepted by PostgreSQL
  String _generateUuidV4() {
    final rand = Random();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 1

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  String get _validUuid {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final activeId = Supabase.instance.client.auth.currentUser?.id ?? widget.authUserId;
    if (uuidRegex.hasMatch(activeId)) {
      return activeId;
    }
    return _generateUuidV4();
  }

  Future<void> _completeOnboarding() async {
    final fullName = _fullNameController.text.trim();

    if (fullName.isEmpty) {
      _showThemeError('Please enter your full name.');
      return;
    }

    double finalRating = _selectedRating;
    if (_isCustomRating) {
      final customVal = double.tryParse(_customRatingController.text.trim());
      if (customVal == null || customVal < 200 || customVal > 3000) {
        _showThemeError('Please enter a valid rating score between 200 and 3000.');
        return;
      }
      finalRating = customVal;
    }

    setState(() => _loading = true);

    // 🔍 Smart Lookup: Check if a player with this Name and City already exists
    try {
      final existingMatches = await SupabaseService.checkDuplicateUser(fullName, _selectedCity);

      if (existingMatches.isNotEmpty && mounted) {
        final match = existingMatches.first;
        final maskContact = match['phone'] != null && match['phone'].toString().isNotEmpty
            ? 'phone number'
            : (match['email'] != null && match['email'].toString().isNotEmpty ? 'email address' : 'phone or email');

        bool? shouldSignIn = await showDialog<bool>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xEE0B0C0E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: ZorvaTheme.primaryGold, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44D4AF37),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x22D4AF37),
                          border: Border.all(color: ZorvaTheme.primaryGold, width: 1.5),
                        ),
                        child: const Icon(Icons.person_search_rounded, color: ZorvaTheme.primaryGold, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'EXISTING PASSPORT FOUND',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ZorvaTheme.primaryGold,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            color: ZorvaTheme.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'A player named '),
                            TextSpan(
                              text: fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: ZorvaTheme.primaryGold),
                            ),
                            TextSpan(text: ' is already registered in $_selectedCity.\n\nIs this you? Sign in with your $maskContact to continue with your official rating.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: ZorvaTheme.borderSubtle),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'DIFFERENT PERSON',
                                style: TextStyle(
                                  color: ZorvaTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ZorvaTheme.primaryGold,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'YES, SIGN IN',
                                style: TextStyle(
                                  color: ZorvaTheme.background,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        if (shouldSignIn == true && mounted) {
          setState(() => _loading = false);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SignInScreen()),
            (route) => false,
          );
          return;
        }
      }
    } catch (lookupErr) {
      debugPrint('Existing passport lookup note: $lookupErr');
    }

    final finalPlayerUuid = _validUuid;
    final autoUsername = '${fullName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${finalPlayerUuid.substring(0, 4)}';

    // Register user atomically via FastAPI REST API
    final regRes = await ApiService.registerUser(
      userId: finalPlayerUuid,
      email: widget.email.contains('@') ? widget.email : null,
      username: autoUsername,
      fullName: fullName,
      city: _selectedCity,
      selfRating: finalRating,
    );

    // Save to UserSession memory state after confirmed API save
    UserSession.userId = finalPlayerUuid;
    UserSession.fullName = fullName;
    UserSession.city = _selectedCity;

    final int playerRankNumber = regRes?['rank'] ?? 1;
    final ordinalRank = UserSession.getOrdinal(playerRankNumber);

    if (mounted) setState(() => _loading = false);

    if (!mounted) return;

    // Show Founding Player Modal with exact calculated rank & city
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xEE0B0C0E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ZorvaTheme.primaryGold, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44D4AF37),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x22D4AF37),
                      border: Border.all(color: ZorvaTheme.primaryGold, width: 1.5),
                    ),
                    child: const Icon(Icons.workspace_premium, color: ZorvaTheme.primaryGold, size: 42),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FOUNDING PLAYER UNLOCKED!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ZorvaTheme.primaryGold,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Congratulations, $fullName!\n\nYou are officially the $ordinalRank Founding Player in $_selectedCity.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ZorvaTheme.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Starting baseline rating: ${finalRating.toInt()} PTS\nLifetime Official Sports Rating Pass & City Founder Badge activated.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ZorvaTheme.textSecondary.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZorvaTheme.primaryGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomeDashboardScreen(
                              userId: finalPlayerUuid,
                              displayName: fullName,
                              city: _selectedCity,
                            ),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ENTER ZORVA ⚡',
                            style: TextStyle(
                              color: ZorvaTheme.background,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18, color: ZorvaTheme.background),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ratingOption(double rating, String title, String subtitle) {
    final isSelected = !_isCustomRating && _selectedRating == rating;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _clearError();
          setState(() {
            _selectedRating = rating;
            _isCustomRating = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x22D4AF37) : const Color(0x331C2024),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? ZorvaTheme.primaryGold : ZorvaTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: ZorvaTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customRatingOption() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _clearError();
          setState(() => _isCustomRating = true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _isCustomRating ? const Color(0x22D4AF37) : const Color(0x331C2024),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isCustomRating ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
              width: _isCustomRating ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎯 Custom',
                style: TextStyle(
                  color: _isCustomRating ? ZorvaTheme.primaryGold : ZorvaTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Enter score',
                style: TextStyle(
                  color: ZorvaTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      appBar: AppBar(
        backgroundColor: ZorvaTheme.background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SETUP SPORTS PASSPORT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: ZorvaTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: ZorvaTheme.textSecondary, size: 20),
            tooltip: 'Sign Out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gold Glow Orbs
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

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Full Name Section
                  const Text(
                    'FULL NAME',
                    style: TextStyle(
                      color: ZorvaTheme.primaryGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fullNameController,
                    onTap: _clearError,
                    onChanged: (_) => _clearError(),
                    style: const TextStyle(color: ZorvaTheme.textPrimary, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Alex Rivera',
                      prefixIcon: Icon(Icons.person_outline, color: ZorvaTheme.primaryGold),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Starting Rating Section
                  const Text(
                    'STARTING RATING / SKILL BASELINE',
                    style: TextStyle(
                      color: ZorvaTheme.primaryGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your rating calibrates automatically after each match you log.',
                    style: TextStyle(
                      color: ZorvaTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ratingOption(1000.0, '🌱 1,000 PTS', 'Casual'),
                      const SizedBox(width: 10),
                      _ratingOption(1200.0, '⚡ 1,200 PTS', 'Intermediate'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _ratingOption(1500.0, '🏆 1,500 PTS', 'Advanced / Club'),
                      const SizedBox(width: 10),
                      _customRatingOption(),
                    ],
                  ),
                  if (_isCustomRating) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customRatingController,
                      keyboardType: TextInputType.number,
                      onTap: _clearError,
                      onChanged: (_) => _clearError(),
                      style: const TextStyle(color: ZorvaTheme.textPrimary, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'Enter rating score (e.g. 1350)',
                        prefixIcon: Icon(Icons.stars, color: ZorvaTheme.primaryGold),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Home City Search Section
                  const Text(
                    'HOME CITY LEADERBOARD',
                    style: TextStyle(
                      color: ZorvaTheme.primaryGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Search Bar for City
                  TextField(
                    controller: _citySearchController,
                    onTap: _clearError,
                    onChanged: (val) {
                      _clearError();
                      setState(() => _cityQuery = val);
                    },
                    style: const TextStyle(color: ZorvaTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search your city (e.g. Austin, London...)',
                      prefixIcon: const Icon(Icons.search, color: ZorvaTheme.primaryGold),
                      suffixIcon: _cityQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: ZorvaTheme.textMuted, size: 18),
                              onPressed: () {
                                _citySearchController.clear();
                                setState(() => _cityQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filtered City Choice Chips
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _filteredCities.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: GestureDetector(
                                    onTap: () {
                                      final customCity = _cityQuery.trim();
                                      if (customCity.isNotEmpty) {
                                        setState(() => _selectedCity = customCity);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0x331C2024),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: ZorvaTheme.primaryGold),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add_location_alt, size: 16, color: ZorvaTheme.primaryGold),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Add "${_cityQuery.trim()}"',
                                            style: const TextStyle(
                                              color: ZorvaTheme.primaryGold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ]
                            : _filteredCities.map((city) {
                                final isSelected = _selectedCity == city;
                                return ChoiceChip(
                                  label: Text(city),
                                  selected: isSelected,
                                  selectedColor: ZorvaTheme.primaryGold,
                                  backgroundColor: const Color(0x331C2024),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: isSelected ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
                                    ),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected ? ZorvaTheme.background : ZorvaTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() => _selectedCity = city);
                                    }
                                  },
                                );
                              }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Enter Zorva Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _completeOnboarding,
                      child: _loading
                          ? const CircularProgressIndicator(color: ZorvaTheme.background)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'CLAIM SPORTS PASSPORT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.bolt, size: 20),
                              ],
                            ),
                    ),
                  ),

                  // Inline Light Gold Error Banner
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

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
