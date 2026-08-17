import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../dashboard/presentation/screens/home_dashboard_screen.dart';
import 'welcome_screen.dart';
import '../../../../core/services/api_service.dart';

class PlayerProfilingScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final String city;

  const PlayerProfilingScreen({
    super.key,
    required this.userId,
    required this.displayName,
    required this.city,
  });

  @override
  State<PlayerProfilingScreen> createState() => _PlayerProfilingScreenState();
}

class _PlayerProfilingScreenState extends State<PlayerProfilingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _customRatingController = TextEditingController();
  int _currentStep = 0;
  bool _saving = false;
  bool _isCustomRatingSelected = false;

  // Selected Answers
  String _playingHand = 'Right Handed';
  String _playstyle = 'Aggressive Attacker';
  String _gripStyle = 'Shakehand';
  String _rubberType = 'Smooth / Inverted';
  String _skillLevel = 'Intermediate';
  double _initialRating = 1200.0;

  final List<Map<String, dynamic>> _questions = [
    {
      'title': 'WHICH HAND DO YOU PLAY WITH?',
      'subtitle': 'Select your dominant playing hand',
      'key': 'playing_hand',
      'options': [
        {'label': 'Right Handed', 'icon': '🖐️', 'desc': 'Standard right-dominant play'},
        {'label': 'Left Handed', 'icon': '🤚', 'desc': 'Southpaw strategic angle advantage'},
        {'label': 'Ambidextrous', 'icon': '🙌', 'desc': 'Capable with both hands'},
      ],
    },
    {
      'title': 'WHAT IS YOUR PLAYING STYLE?',
      'subtitle': 'Select your primary match tactic',
      'key': 'playstyle',
      'options': [
        {'label': 'Aggressive Attacker', 'icon': '⚡', 'desc': 'Heavy topspin, loops, and smashes'},
        {'label': 'Defensive Control', 'icon': '🛡️', 'desc': 'Backspin chops, pushes, and blocks'},
        {'label': 'All-Round Balanced', 'icon': '⚖️', 'desc': 'Adaptable counter-drives and placement'},
      ],
    },
    {
      'title': 'HOW DO YOU HOLD YOUR RACKET?',
      'subtitle': 'Select your preferred grip style',
      'key': 'grip_style',
      'options': [
        {'label': 'Shakehand', 'icon': '🤝', 'desc': 'Standard Western handle grip'},
        {'label': 'Penhold', 'icon': '🖊️', 'desc': 'Traditional Asian pen-like grip'},
        {'label': 'Casual / Not Sure', 'icon': '❓', 'desc': 'Recreational or flexible grip'},
      ],
    },
    {
      'title': 'WHAT TYPE OF RUBBER DO YOU USE?',
      'subtitle': 'Select rubber equipment technology',
      'key': 'rubber_type',
      'options': [
        {'label': 'Smooth / Inverted', 'icon': '🔴', 'desc': 'High spin & speed (Standard)'},
        {'label': 'Short Pips', 'icon': '🏓', 'desc': 'Fast attack, hit through opponent spin'},
        {'label': 'Long Pips / Anti-Spin', 'icon': '🧪', 'desc': 'Spin reversal & unpredictable spin'},
        {'label': 'Standard / Not Sure', 'icon': '⚙️', 'desc': 'Pre-assembled recreational racket'},
      ],
    },
    {
      'title': 'ESTIMATE YOUR EXPERIENCE LEVEL',
      'subtitle': 'Calibrates your starting baseline rating',
      'key': 'self_assessed_level',
      'options': [
        {
          'label': 'Casual / Recreational',
          'icon': '🌱',
          'desc': 'Basements, apartments, office breakrooms (1,000 PTS)',
          'rating': 1000.0,
          'rd': 350.0,
        },
        {
          'label': 'Intermediate / Club Regular',
          'icon': '⚡',
          'desc': 'Plays regularly, good ball placement (1,200 PTS)',
          'rating': 1200.0,
          'rd': 350.0,
        },
        {
          'label': 'Advanced / Tournament Player',
          'icon': '🏆',
          'desc': 'Competitive league or rating experience (1,500 PTS)',
          'rating': 1500.0,
          'rd': 300.0,
        },
        {
          'label': 'Enter Custom Known Rating',
          'icon': '🎯',
          'desc': 'Specify your exact USATT, State, or Club rating',
          'isCustom': true,
        },
      ],
    },
  ];

  void _onOptionSelected(int qIndex, Map<String, dynamic> option) {
    if (qIndex == 4 && option['isCustom'] == true) {
      setState(() {
        _isCustomRatingSelected = true;
        _skillLevel = 'Custom Rating';
      });
      return;
    }

    setState(() {
      _isCustomRatingSelected = false;
      if (qIndex == 0) _playingHand = option['label'];
      if (qIndex == 1) _playstyle = option['label'];
      if (qIndex == 2) _gripStyle = option['label'];
      if (qIndex == 3) _rubberType = option['label'];
      if (qIndex == 4) {
        _skillLevel = option['label'];
        _initialRating = option['rating'] ?? 1200.0;
      }
    });

    if (qIndex < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfileAndFinish();
    }
  }

  Future<void> _saveProfileAndFinish() async {
    if (_isCustomRatingSelected) {
      final customVal = double.tryParse(_customRatingController.text.trim());
      if (customVal == null || customVal < 200 || customVal > 3000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid rating score (e.g. 1450).')),
        );
        return;
      }
      _initialRating = customVal;
    }

    setState(() => _saving = true);

    try {
      // Save profiling attributes and calibrated rating via REST API
      try {
        await ApiService.updateUserProfile(widget.userId, {
          'play_style': _playstyle,
          'playing_hand': _playingHand,
          'grip_style': _gripStyle,
          'rubber_type': _rubberType,
          'skill_level': _skillLevel,
          'self_rating': _initialRating,
        });
      } catch (rErr) {
        debugPrint('Calibrated rating save note: $rErr');
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomeDashboardScreen(userId: widget.userId)),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Profiling error: $e');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomeDashboardScreen(userId: widget.userId)),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: Text(
          'SPORTS PASSPORT (${_currentStep + 1}/${_questions.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: ZorvaTheme.primaryGold,
            letterSpacing: 1.5,
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
          TextButton(
            onPressed: _saving ? null : _saveProfileAndFinish,
            child: const Text(
              'SKIP',
              style: TextStyle(
                color: ZorvaTheme.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gold Radial Glow
          Positioned(
            top: -60,
            left: size.width * 0.1,
            width: size.width * 0.8,
            height: 300,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: ZorvaTheme.goldGlowAura,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  // Step Progress Bar
                  Row(
                    children: List.generate(
                      _questions.length,
                      (idx) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 4,
                          decoration: BoxDecoration(
                            color: idx <= _currentStep
                                ? ZorvaTheme.primaryGold
                                : ZorvaTheme.borderSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Page View Questions
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (idx) => setState(() => _currentStep = idx),
                      itemCount: _questions.length,
                      itemBuilder: (context, qIndex) {
                        final q = _questions[qIndex];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q['title'],
                              style: const TextStyle(
                                color: ZorvaTheme.primaryGold,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              q['subtitle'],
                              style: const TextStyle(
                                color: ZorvaTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Option Cards
                            Expanded(
                              child: ListView.builder(
                                itemCount: (q['options'] as List).length,
                                itemBuilder: (context, oIndex) {
                                  final option = q['options'][oIndex];
                                  final isSelected =
                                      (qIndex == 0 && _playingHand == option['label']) ||
                                      (qIndex == 1 && _playstyle == option['label']) ||
                                      (qIndex == 2 && _gripStyle == option['label']) ||
                                      (qIndex == 3 && _rubberType == option['label']) ||
                                      (qIndex == 4 && _skillLevel == option['label']);

                                  return Column(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _onOptionSelected(qIndex, option),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0x22D4AF37)
                                                : const Color(0x331C2024),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? ZorvaTheme.primaryGold
                                                  : ZorvaTheme.borderSubtle,
                                              width: isSelected ? 1.8 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                option['icon'],
                                                style: const TextStyle(fontSize: 28),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      option['label'],
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? ZorvaTheme.primaryGold
                                                            : ZorvaTheme.textPrimary,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      option['desc'],
                                                      style: const TextStyle(
                                                        color: ZorvaTheme.textSecondary,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (isSelected)
                                                const Icon(
                                                  Icons.check_circle,
                                                  color: ZorvaTheme.primaryGold,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (qIndex == 4 &&
                                          option['isCustom'] == true &&
                                          _isCustomRatingSelected) ...[
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 16),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF14171A),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: ZorvaTheme.primaryGold),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'ENTER KNOWN RATING SCORE',
                                                style: TextStyle(
                                                  color: ZorvaTheme.primaryGold,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: _customRatingController,
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(
                                                  color: ZorvaTheme.textPrimary,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                decoration: const InputDecoration(
                                                  hintText: 'e.g. 1450',
                                                  prefixIcon: Icon(Icons.stars, color: ZorvaTheme.primaryGold),
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 48,
                                                child: ElevatedButton(
                                                  onPressed: _saveProfileAndFinish,
                                                  child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        'CONFIRM RATING & ENTER ZORVA ⚡',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: ZorvaTheme.primaryGold),
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
