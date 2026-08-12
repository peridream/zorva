import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../../core/constants/supabase_constants.dart';

class AddMatchScreen extends StatefulWidget {
  const AddMatchScreen({super.key});

  @override
  State<AddMatchScreen> createState() => _AddMatchScreenState();
}

class _AddMatchScreenState extends State<AddMatchScreen> {
  bool _loadingUsers = true;
  bool _submitting = false;

  List<Map<String, dynamic>> _opponents = [];
  String _selectedOpponentId = '';

  // Match Configuration & Eligibility
  bool _isBothOfficial = false;
  String _matchType = 'community'; // 'community' or 'official'
  int _setFormat = 3; // 3 or 5
  bool _iWon = true;
  int _selectedPresetIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchOpponents();
  }

  Future<void> _fetchOpponents() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id ?? SupabaseConstants.currentUserId;

    try {
      final res = await supabase
          .from('profiles')
          .select()
          .neq('id', userId);
      setState(() {
        _opponents = List<Map<String, dynamic>>.from(res).take(3).toList();
        if (_opponents.isNotEmpty) {
          _selectedOpponentId = _opponents.first['id'];
        }
      });
    } catch (e) {
      debugPrint('Error fetching opponents: $e');
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  void _showSearchOpponentModal() async {
    final supabase = Supabase.instance.client;
    final userId = SupabaseConstants.currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String searchQuery = '';
        List<Map<String, dynamic>> allUsers = [];
        bool loadingSearch = true;

        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loadingSearch) {
              supabase
                  .from('profiles')
                  .select()
                  .neq('id', userId)
                  .then((res) {
                if (mounted) {
                  setModalState(() {
                    allUsers = List<Map<String, dynamic>>.from(res);
                    loadingSearch = false;
                  });
                }
              }).catchError((_) {
                if (mounted) setModalState(() => loadingSearch = false);
              });
            }

            final filtered = allUsers.where((u) {
              final name = (u['full_name'] ?? u['username'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'FIND OPPONENT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: ZorvaTheme.primaryGold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    style: const TextStyle(color: ZorvaTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Search player name or city...',
                      prefixIcon: Icon(Icons.search, color: ZorvaTheme.primaryGold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: loadingSearch
                        ? const Center(child: CircularProgressIndicator(color: ZorvaTheme.primaryGold))
                        : filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No other players found yet.',
                                  style: TextStyle(color: ZorvaTheme.textMuted),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final u = filtered[idx];
                                  final name = u['full_name'] ?? u['username'] ?? 'Player';
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: ZorvaTheme.primaryGold,
                                      child: Text(
                                        name[0].toUpperCase(),
                                        style: const TextStyle(color: ZorvaTheme.background, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(color: ZorvaTheme.textPrimary, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '📍 ${u['city'] ?? 'Austin'}',
                                      style: const TextStyle(color: ZorvaTheme.textMuted, fontSize: 12),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        if (!_opponents.any((o) => o['id'] == u['id'])) {
                                          _opponents.add(u);
                                        }
                                        _selectedOpponentId = u['id'];
                                      });
                                      if (context.mounted) Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _getPresets() {
    final isBestOf3 = _setFormat == 3;

    if (_iWon) {
      if (isBestOf3) {
        return [
          {
            'label': '2 - 0 (Clean Win)',
            'sets': [
              [11, 8],
              [11, 9]
            ]
          },
          {
            'label': '2 - 1 (Close Win)',
            'sets': [
              [11, 9],
              [9, 11],
              [11, 7]
            ]
          },
        ];
      } else {
        return [
          {
            'label': '3 - 0 (Sweep Win)',
            'sets': [
              [11, 7],
              [11, 8],
              [11, 9]
            ]
          },
          {
            'label': '3 - 1 (Standard Win)',
            'sets': [
              [11, 9],
              [9, 11],
              [11, 8],
              [11, 7]
            ]
          },
          {
            'label': '3 - 2 (5-Set Win)',
            'sets': [
              [11, 9],
              [8, 11],
              [11, 8],
              [9, 11],
              [11, 7]
            ]
          },
        ];
      }
    } else {
      if (isBestOf3) {
        return [
          {
            'label': '0 - 2 (Clean Loss)',
            'sets': [
              [8, 11],
              [9, 11]
            ]
          },
          {
            'label': '1 - 2 (Close Loss)',
            'sets': [
              [9, 11],
              [11, 9],
              [7, 11]
            ]
          },
        ];
      } else {
        return [
          {
            'label': '0 - 3 (Sweep Loss)',
            'sets': [
              [7, 11],
              [8, 11],
              [9, 11]
            ]
          },
          {
            'label': '1 - 3 (Standard Loss)',
            'sets': [
              [9, 11],
              [11, 9],
              [8, 11],
              [7, 11]
            ]
          },
          {
            'label': '2 - 3 (5-Set Loss)',
            'sets': [
              [9, 11],
              [11, 8],
              [8, 11],
              [11, 9],
              [7, 11]
            ]
          },
        ];
      }
    }
  }

  Future<void> _submitMatch() async {
    if (_selectedOpponentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an opponent.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final supabase = Supabase.instance.client;
    final p1 = supabase.auth.currentUser?.id ?? SupabaseConstants.currentUserId;
    final p2 = _selectedOpponentId;
    final winner = _iWon ? p1 : p2;

    final presets = _getPresets();
    final selectedPreset = presets[_selectedPresetIndex % presets.length];
    final List<List<int>> sets = List<List<int>>.from(selectedPreset['sets'] ?? []);

    int creatorWonSets = 0;
    int opponentWonSets = 0;
    for (final s in sets) {
      if (s[0] > s[1]) {
        creatorWonSets++;
      } else {
        opponentWonSets++;
      }
    }

    final creatorScore = creatorWonSets;
    final opponentScore = opponentWonSets;

    try {
      // Auto-detect shared group between p1 and p2
      String? matchedGroupId;
      try {
        final p1Groups = await supabase.from('group_members').select('group_id').eq('user_id', p1);
        final p2Groups = await supabase.from('group_members').select('group_id').eq('user_id', p2);

        final p1Gids = (p1Groups as List).map((g) => g['group_id'] as String).toSet();
        final p2Gids = (p2Groups as List).map((g) => g['group_id'] as String).toSet();
        final common = p1Gids.intersection(p2Gids);
        if (common.isNotEmpty) {
          matchedGroupId = common.first;
        }
      } catch (gErr) {
        debugPrint('Group detection note: $gErr');
      }

      final Map<String, dynamic> matchPayload = {
        'creator_id': p1,
        'opponent_id': p2,
        'sport': 'table_tennis',
        'creator_score': creatorScore,
        'opponent_score': opponentScore,
        'winner_id': winner,
        'status': 'pending',
        'logged_at': DateTime.now().toIso8601String(),
      };
      if (matchedGroupId != null) {
        matchPayload['group_id'] = matchedGroupId;
      }

      await supabase.from('matches').insert(matchPayload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZorvaTheme.primaryGold,
            content: Text(
              '⚡ Match Logged (<10s)! Sent to opponent for approval.',
              style: TextStyle(color: ZorvaTheme.background, fontWeight: FontWeight.bold),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error logging match: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Match logged locally! ($e)'),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = _getPresets();

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      appBar: AppBar(
        backgroundColor: ZorvaTheme.background,
        elevation: 0,
        title: const Text(
          'SUB-10s MATCH LOGGER',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: ZorvaTheme.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. SELECT RECENT OPPONENT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SELECT OPPONENT',
                style: TextStyle(
                  color: ZorvaTheme.primaryGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: _showSearchOpponentModal,
                child: const Row(
                  children: [
                    Icon(Icons.search, color: ZorvaTheme.primaryGold, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'FIND OTHER PLAYER',
                      style: TextStyle(
                        color: ZorvaTheme.primaryGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingUsers)
            const Center(child: CircularProgressIndicator(color: ZorvaTheme.primaryGold))
          else if (_opponents.isEmpty)
            GestureDetector(
              onTap: _showSearchOpponentModal,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x331C2024),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZorvaTheme.primaryGold),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add, color: ZorvaTheme.primaryGold, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Search Player to Start Match',
                      style: TextStyle(color: ZorvaTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _opponents.map((u) {
                final isSelected = _selectedOpponentId == u['id'];
                final name = u['full_name'] ?? u['username'] ?? 'Player';
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedOpponentId = u['id']);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0x22D4AF37) : const Color(0x331C2024),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              isSelected ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? ZorvaTheme.background : ZorvaTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$name (📍 ${u['city'] ?? 'Austin'})',
                            style: TextStyle(
                              color: isSelected
                                  ? ZorvaTheme.primaryGold
                                  : ZorvaTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: ZorvaTheme.primaryGold),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // 2. SET FORMAT SELECTOR
          Row(
            children: [
              const Text(
                'MATCH FORMAT:',
                style: TextStyle(
                  color: ZorvaTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('BEST OF 3'),
                selected: _setFormat == 3,
                selectedColor: ZorvaTheme.primaryGold,
                backgroundColor: const Color(0x331C2024),
                labelStyle: TextStyle(
                  color: _setFormat == 3 ? ZorvaTheme.background : ZorvaTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) => setState(() {
                  _setFormat = 3;
                  _selectedPresetIndex = 0;
                }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('BEST OF 5'),
                selected: _setFormat == 5,
                selectedColor: ZorvaTheme.primaryGold,
                backgroundColor: const Color(0x331C2024),
                labelStyle: TextStyle(
                  color: _setFormat == 5 ? ZorvaTheme.background : ZorvaTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                onSelected: (val) => setState(() {
                  _setFormat = 5;
                  _selectedPresetIndex = 0;
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. RESULT TOGGLE (I WON VS I LOST)
          const Text(
            'MATCH RESULT',
            style: TextStyle(
              color: ZorvaTheme.primaryGold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _iWon
                        ? Colors.greenAccent.withOpacity(0.15)
                        : const Color(0x331C2024),
                    side: BorderSide(
                      color: _iWon ? Colors.greenAccent : ZorvaTheme.borderSubtle,
                      width: _iWon ? 2 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => setState(() {
                    _iWon = true;
                    _selectedPresetIndex = 0;
                  }),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events,
                          color: _iWon ? Colors.greenAccent : ZorvaTheme.textMuted,
                          size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'I WON ⚡',
                        style: TextStyle(
                          color: _iWon ? Colors.greenAccent : ZorvaTheme.textMuted,
                          fontWeight: FontWeight.w900,
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
                    backgroundColor: !_iWon
                        ? Colors.redAccent.withOpacity(0.15)
                        : const Color(0x331C2024),
                    side: BorderSide(
                      color: !_iWon ? Colors.redAccent : ZorvaTheme.borderSubtle,
                      width: !_iWon ? 2 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => setState(() {
                    _iWon = false;
                    _selectedPresetIndex = 0;
                  }),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.heart_broken,
                          color: !_iWon ? Colors.redAccent : ZorvaTheme.textMuted,
                          size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'I LOST 💔',
                        style: TextStyle(
                          color: !_iWon ? Colors.redAccent : ZorvaTheme.textMuted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. SCORE PRESETS
          Text(
            _iWon ? 'QUICK SCORE PRESET (WIN)' : 'QUICK SCORE PRESET (LOSS)',
            style: TextStyle(
              color: _iWon ? Colors.greenAccent : Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: List.generate(presets.length, (pIndex) {
              final p = presets[pIndex];
              final isSelected = _selectedPresetIndex == pIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedPresetIndex = pIndex),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0x22D4AF37)
                        : const Color(0x331C2024),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p['label'],
                        style: TextStyle(
                          color: isSelected
                              ? ZorvaTheme.primaryGold
                              : ZorvaTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: ZorvaTheme.primaryGold),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // 5. LOG MATCH BUTTON
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitMatch,
              child: _submitting
                  ? const CircularProgressIndicator(color: ZorvaTheme.background)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'LOG MATCH RESULT (< 10S)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 1.5,
                          ),
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
