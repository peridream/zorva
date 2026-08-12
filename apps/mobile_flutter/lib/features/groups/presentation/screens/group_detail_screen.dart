import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../../core/services/api_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final String userId;

  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.userId,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroupData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    setState(() => _loading = true);
    final groupId = widget.group['id'] ?? '';
    
    final lb = await ApiService.getGroupLeaderboard(groupId);
    final ins = await ApiService.getGroupInsights(groupId, widget.userId);

    if (mounted) {
      setState(() {
        _leaderboard = lb;
        _insights = ins;
        _loading = false;
      });
    }
  }

  void _copyInviteCode() {
    final code = widget.group['invite_code'] ?? '';
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite Code $code copied to clipboard!'),
          backgroundColor: ZorvaTheme.primaryGold,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.group['name'] ?? 'Community Group';
    final city = widget.group['city'] ?? 'Dallas';
    final sport = widget.group['sport'] ?? 'Table Tennis';
    final gType = widget.group['group_type'] ?? 'community';
    final isFlagship = gType == 'flagship';
    final inviteCode = widget.group['invite_code'] ?? 'ZORVA';
    final memberCount = _leaderboard.length;
    final maxMembers = widget.group['max_members'] ?? 20;

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF14171A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ZorvaTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                groupName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ZorvaTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isFlagship ? ZorvaTheme.primaryGold.withOpacity(0.18) : Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFlagship ? ZorvaTheme.primaryGold : Colors.blueAccent,
                  width: 0.7,
                ),
              ),
              child: Text(
                isFlagship ? 'FLAGSHIP ⚡' : 'COMMUNITY 🎾',
                style: TextStyle(
                  color: isFlagship ? ZorvaTheme.primaryGold : Colors.blueAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _copyInviteCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2024),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZorvaTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        inviteCode,
                        style: const TextStyle(
                          color: ZorvaTheme.primaryGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, color: ZorvaTheme.textMuted, size: 13),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [

          // Tab Bar
          Container(
            color: const Color(0xFF14171A),
            child: TabBar(
              controller: _tabController,
              indicatorColor: ZorvaTheme.primaryGold,
              labelColor: ZorvaTheme.primaryGold,
              unselectedLabelColor: ZorvaTheme.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'LEADERBOARD 🏆'),
                Tab(text: 'GROUP INSIGHTS 📈'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: ZorvaTheme.primaryGold))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLeaderboardTab(),
                      _buildInsightsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    if (_leaderboard.isEmpty) {
      return const Center(
        child: Text(
          'No group members found.',
          style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaderboard.length,
      itemBuilder: (ctx, idx) {
        final m = _leaderboard[idx];
        final rank = m['rank'] ?? (idx + 1);
        final name = m['name'] ?? 'Player';
        final rating = m['rating'] ?? 1500;
        final role = m['role'] ?? 'member';

        Color rankColor = ZorvaTheme.textMuted;
        if (rank == 1) rankColor = const Color(0xFFFFD700);
        if (rank == 2) rankColor = const Color(0xFFC0C0C0);
        if (rank == 3) rankColor = const Color(0xFFCD7F32);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF14171A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ZorvaTheme.borderSubtle),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: ZorvaTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (role == 'admin') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZorvaTheme.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ADMIN',
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
              ),
              Text(
                '$rating pts',
                style: const TextStyle(
                  color: ZorvaTheme.primaryGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightsTab() {
    final isUnlocked = _insights?['is_unlocked'] == true;

    if (!isUnlocked) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF14171A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ZorvaTheme.primaryGold, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ZorvaTheme.primaryGold.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: ZorvaTheme.primaryGold, size: 40),
              ),
              const SizedBox(height: 18),
              const Text(
                'FLAGSHIP INSIGHTS LOCKED 🏆',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ZorvaTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _insights?['message'] ??
                    'Group Insights are exclusive to Flagship Subscribers. Upgrade to unlock internal group rivalries, win rate analytics & form metrics!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZorvaTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZorvaTheme.primaryGold,
                  foregroundColor: ZorvaTheme.background,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Upgrade modal opened! Choose Founder Flagship plan.'),
                      backgroundColor: ZorvaTheme.primaryGold,
                    ),
                  );
                },
                child: const Text(
                  'UPGRADE TO FLAGSHIP ⚡',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Unlocked Flagship Insights
    final totalMatches = _insights?['total_group_matches'] ?? 0;
    final activeCount = _insights?['active_members_count'] ?? 0;
    final topRivalry = _insights?['top_group_rivalry'] ?? 'None';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GROUP ANALYTICS',
            style: TextStyle(
              color: ZorvaTheme.primaryGold,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildInsightMetricCard('Group Matches', '$totalMatches', Icons.sports_tennis_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightMetricCard('Active Members', '$activeCount', Icons.people_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInsightMetricCard('Top Internal Rivalry', topRivalry, Icons.local_fire_department_rounded),
        ],
      ),
    );
  }

  Widget _buildInsightMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14171A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZorvaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ZorvaTheme.primaryGold, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: ZorvaTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: ZorvaTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
