import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../../core/constants/supabase_constants.dart';

class LeaderboardsScreen extends StatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends State<LeaderboardsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _contexts = [];
  String _selectedContextId = '';
  String _selectedCity = 'ALL';
  List<String> _cities = ['ALL'];
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboardData();
  }

  Future<void> _loadLeaderboardData() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      final ctxRes = await supabase.from('rating_contexts').select();
      final allContexts = List<Map<String, dynamic>>.from(ctxRes);

      // Official Leaderboard: Exclude general community rating context
      _contexts = allContexts.where((c) => c['type'] != 'community').toList();

      if (_contexts.isEmpty && allContexts.isNotEmpty) {
        _contexts = [allContexts.first];
      }

      if (_selectedContextId.isEmpty && _contexts.isNotEmpty) {
        _selectedContextId = _contexts.first['id'];
      }

      if (_selectedContextId.isNotEmpty) {
        final lbRes = await supabase
            .from('player_context_ratings')
            .select('*, profiles!user_id(id, username, full_name, city)')
            .eq('context_id', _selectedContextId)
            .order('rating', ascending: false);

        List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(lbRes);

        final setOfCities = {'ALL'};
        for (var e in rawList) {
          final c = e['profiles']?['city'] as String?;
          if (c != null && c.trim().isNotEmpty) {
            setOfCities.add(c.trim());
          }
        }
        _cities = setOfCities.toList();

        if (_selectedCity != 'ALL') {
          rawList = rawList.where((e) {
            final c = (e['profiles']?['city'] as String? ?? '').trim();
            return c.toLowerCase() == _selectedCity.toLowerCase();
          }).toList();
        }

        _leaderboard = rawList;
      }
    } catch (e) {
      debugPrint('Error loading leaderboards: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      appBar: AppBar(
        title: const Text(
          'CITY RANKINGS & LEADERBOARD',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: ZorvaTheme.primaryGold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZorvaTheme.primaryGold))
          : RefreshIndicator(
              color: ZorvaTheme.primaryGold,
              onRefresh: _loadLeaderboardData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Context Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _contexts.map((ctx) {
                        final isSelected = ctx['id'] == _selectedContextId;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedContextId = ctx['id']);
                            _loadLeaderboardData();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? ZorvaTheme.primaryGold
                                  : ZorvaTheme.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? ZorvaTheme.primaryGold
                                    : ZorvaTheme.borderDark,
                              ),
                            ),
                            child: Text(
                              (ctx['name'] as String).toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.black : ZorvaTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // City Filter Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CITY RANKINGS',
                        style: TextStyle(
                          color: ZorvaTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2024),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ZorvaTheme.borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCity,
                            dropdownColor: const Color(0xFF1C2024),
                            style: const TextStyle(
                              color: ZorvaTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            items: _cities
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c == 'ALL' ? '🌐 All Cities' : '📍 $c'),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCity = val);
                                _loadLeaderboardData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_leaderboard.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: ZorvaTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ZorvaTheme.borderDark),
                      ),
                      child: const Center(
                        child: Text(
                          'No ranked players in this category yet. Log a match to enter!',
                          style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: List.generate(_leaderboard.length, (idx) {
                        final entry = _leaderboard[idx];
                        final user = entry['profiles'] ?? {};
                        final rawName = user['full_name'] ?? user['username'];
                        final name = (rawName != null && rawName.toString().trim().isNotEmpty)
                            ? rawName.toString().trim()
                            : 'Player';
                        final city = user['city'] ?? '—';
                        final rating = (entry['rating'] as num).round();
                        final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? SupabaseConstants.currentUserId;
                        final isCurrentUser = user['id'] == currentUserId;
                        final rank = idx + 1;

                        Color rankBadgeColor = ZorvaTheme.cardBg;
                        Color rankTextColor = ZorvaTheme.textMuted;
                        String badgeIcon = '#$rank';

                        if (rank == 1) {
                          rankBadgeColor = const Color(0xFFF7D070);
                          rankTextColor = Colors.black;
                          badgeIcon = '🥇';
                        } else if (rank == 2) {
                          rankBadgeColor = const Color(0xFFE2E8F0);
                          rankTextColor = Colors.black;
                          badgeIcon = '🥈';
                        } else if (rank == 3) {
                          rankBadgeColor = const Color(0xFFF97316);
                          rankTextColor = Colors.black;
                          badgeIcon = '🥉';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: isCurrentUser
                                ? ZorvaTheme.darkCardGradient
                                : null,
                            color: isCurrentUser ? null : ZorvaTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentUser
                                  ? ZorvaTheme.borderGold
                                  : ZorvaTheme.borderDark,
                              width: isCurrentUser ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: rankBadgeColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    badgeIcon,
                                    style: TextStyle(
                                      color: rankTextColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: rank <= 3 ? 16 : 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: isCurrentUser
                                                ? ZorvaTheme.primaryGold
                                                : ZorvaTheme.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ZorvaTheme.primaryGold
                                                  .withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'YOU',
                                              style: TextStyle(
                                                color: ZorvaTheme.primaryGold,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📍 $city',
                                      style: const TextStyle(
                                        color: ZorvaTheme.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$rating',
                                style: const TextStyle(
                                  color: ZorvaTheme.primaryGold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'PTS',
                                style: TextStyle(
                                  color: ZorvaTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
    );
  }
}
