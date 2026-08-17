import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/supabase_service.dart';

class LeaderboardsScreen extends StatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends State<LeaderboardsScreen> {
  bool _loading = true;

  // Scope: 'city' or 'groups'
  String _activeScope = 'city';

  // City Leaderboard State
  List<Map<String, dynamic>> _contexts = [];
  String _selectedContextId = '';
  String _selectedCity = 'ALL';
  List<String> _cities = ['ALL'];
  List<Map<String, dynamic>> _cityLeaderboard = [];

  // Group Leaderboard State
  List<Map<String, dynamic>> _userGroups = [];
  String _selectedGroupId = '';
  List<Map<String, dynamic>> _groupLeaderboard = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadCityLeaderboardData(),
      _loadUserGroupsData(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCityLeaderboardData() async {
    try {
      final allContexts = await SupabaseService.getRatingContexts();

      _contexts = allContexts.where((c) => c['type'] != 'community').toList();
      if (_contexts.isEmpty && allContexts.isNotEmpty) {
        _contexts = [allContexts.first];
      }

      if (_selectedContextId.isEmpty && _contexts.isNotEmpty) {
        _selectedContextId = _contexts.first['id'];
      }

      if (_selectedContextId.isNotEmpty) {
        List<Map<String, dynamic>> rawList = await SupabaseService.getLeaderboard(_selectedContextId);

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

        _cityLeaderboard = rawList;
      }
    } catch (e) {
      debugPrint('Error loading city leaderboards: $e');
    }
  }

  Future<void> _loadUserGroupsData() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? SupabaseConstants.currentUserId;
    try {
      final groups = await ApiService.getUserGroups(currentUserId);
      _userGroups = groups;

      if (_userGroups.isNotEmpty) {
        if (_selectedGroupId.isEmpty || !_userGroups.any((g) => g['id'] == _selectedGroupId)) {
          _selectedGroupId = _userGroups.first['id'] ?? '';
        }
        await _loadGroupLeaderboardData();
      } else {
        _groupLeaderboard = [];
      }
    } catch (e) {
      debugPrint('Error loading user groups: $e');
    }
  }

  Future<void> _loadGroupLeaderboardData() async {
    if (_selectedGroupId.isEmpty) return;
    try {
      final gLb = await ApiService.getGroupLeaderboard(_selectedGroupId);
      _groupLeaderboard = gLb;
    } catch (e) {
      debugPrint('Error loading group leaderboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      appBar: AppBar(
        backgroundColor: ZorvaTheme.background,
        elevation: 0,
        title: const Text(
          'RANKINGS & LEADERBOARDS',
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
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Scope Toggle Chips: CITY RANKINGS vs MY GROUPS
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ZorvaTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeScope = 'city'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeScope == 'city'
                                    ? ZorvaTheme.primaryGold
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'CITY RANKINGS 🏙️',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _activeScope == 'city'
                                      ? ZorvaTheme.background
                                      : ZorvaTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeScope = 'groups'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _activeScope == 'groups'
                                    ? ZorvaTheme.primaryGold
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'MY GROUPS 👥',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _activeScope == 'groups'
                                      ? ZorvaTheme.background
                                      : ZorvaTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_activeScope == 'city') ...[
                    // Context Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _contexts.map((ctx) {
                          final isSelected = ctx['id'] == _selectedContextId;
                          return GestureDetector(
                            onTap: () async {
                              setState(() => _selectedContextId = ctx['id']);
                              await _loadCityLeaderboardData();
                              if (mounted) setState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          'OFFICIAL CITY STANDINGS',
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
                              onChanged: (val) async {
                                if (val != null) {
                                  setState(() => _selectedCity = val);
                                  await _loadCityLeaderboardData();
                                  if (mounted) setState(() {});
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_cityLeaderboard.isEmpty)
                      _buildEmptyCard('No ranked players in this category yet. Log a match to enter!')
                    else
                      Column(
                        children: List.generate(_cityLeaderboard.length, (idx) {
                          final entry = _cityLeaderboard[idx];
                          final user = entry['profiles'] ?? {};
                          final rawName = user['full_name'] ?? user['username'];
                          final name = (rawName != null && rawName.toString().trim().isNotEmpty)
                              ? rawName.toString().trim()
                              : 'Player';
                          final city = user['city'] ?? '—';
                          final rating = (entry['rating'] as num).round();
                          final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? SupabaseConstants.currentUserId;
                          final isCurrentUser = user['id'] == currentUserId;
                          return _buildLeaderboardTile(
                            rank: idx + 1,
                            name: name,
                            subtitle: '📍 $city',
                            rating: rating,
                            isCurrentUser: isCurrentUser,
                          );
                        }),
                      ),
                  ] else ...[
                    // GROUP LEADERBOARD VIEW
                    if (_userGroups.isEmpty)
                      _buildEmptyCard('You have not joined any groups yet! Go to the Groups tab to join or create one.')
                    else ...[
                      // Group Selector Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _userGroups.map((g) {
                            final gId = g['id'] ?? '';
                            final isSelected = gId == _selectedGroupId;
                            final gName = g['name'] ?? 'Group';
                            final isFlagship = g['group_type'] == 'flagship';

                            return GestureDetector(
                              onTap: () async {
                                setState(() => _selectedGroupId = gId);
                                await _loadGroupLeaderboardData();
                                if (mounted) setState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? ZorvaTheme.primaryGold : ZorvaTheme.cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? ZorvaTheme.primaryGold : ZorvaTheme.borderDark,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      isFlagship ? '⚡ $gName' : '🎾 $gName',
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : ZorvaTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'GROUP STANDINGS',
                            style: TextStyle(
                              color: ZorvaTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            '${_groupLeaderboard.length} MEMBERS',
                            style: const TextStyle(
                              color: ZorvaTheme.primaryGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_groupLeaderboard.isEmpty)
                        _buildEmptyCard('No members on this group leaderboard yet.')
                      else
                        Column(
                          children: List.generate(_groupLeaderboard.length, (idx) {
                            final entry = _groupLeaderboard[idx];
                            final name = entry['name'] ?? 'Player';
                            final city = entry['city'] ?? '';
                            final role = entry['role'] ?? 'member';
                            final rating = (entry['rating'] as num? ?? 1200).round();
                            final uId = entry['user_id'] ?? '';
                            final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? SupabaseConstants.currentUserId;
                            final isCurrentUser = uId == currentUserId;

                            return _buildLeaderboardTile(
                              rank: idx + 1,
                              name: name,
                              subtitle: role == 'admin' ? '👑 Admin · 📍 $city' : '📍 $city',
                              rating: rating,
                              isCurrentUser: isCurrentUser,
                            );
                          }),
                        ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ZorvaTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZorvaTheme.borderDark),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZorvaTheme.textMuted, fontSize: 13, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile({
    required int rank,
    required String name,
    required String subtitle,
    required int rating,
    required bool isCurrentUser,
    bool isFounder = false,
  }) {
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
        gradient: isCurrentUser ? ZorvaTheme.darkCardGradient : null,
        color: isCurrentUser ? null : ZorvaTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? ZorvaTheme.borderGold : ZorvaTheme.borderDark,
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
                        color: isCurrentUser ? ZorvaTheme.primaryGold : ZorvaTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isFounder) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZorvaTheme.primaryGold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: ZorvaTheme.primaryGold, width: 0.8),
                        ),
                        child: const Text(
                          'FOUNDER 👑',
                          style: TextStyle(
                            color: ZorvaTheme.primaryGold,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZorvaTheme.primaryGold.withValues(alpha: 0.2),
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
                  subtitle,
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
  }
}

