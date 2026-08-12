import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../../core/services/api_service.dart';
import '../../../dashboard/presentation/screens/home_dashboard_screen.dart';

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

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
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
    final gType = widget.group['group_type'] ?? 'community';
    final isFlagship = gType == 'flagship';
    final inviteCode = widget.group['invite_code'] ?? 'ZORVA';

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF14171A),
          border: Border(top: BorderSide(color: ZorvaTheme.borderSubtle)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZorvaTheme.primaryGold,
                    foregroundColor: ZorvaTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomeDashboardScreen(
                          userId: widget.userId,
                          initialTabIndex: 0,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.badge_rounded, size: 18, color: ZorvaTheme.background),
                  label: const Text(
                    'GO TO MY PASSPORT 📇',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZorvaTheme.primaryGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // INSIGHTS METRICS SECTION
                  const Text(
                    'GROUP INSIGHTS & ANALYTICS 📈',
                    style: TextStyle(
                      color: ZorvaTheme.primaryGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_insights?['is_unlocked'] == false) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ZorvaTheme.primaryGold.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.lock_rounded, color: ZorvaTheme.primaryGold, size: 32),
                          const SizedBox(height: 10),
                          const Text(
                            'FLAGSHIP INSIGHTS LOCKED 🏆',
                            style: TextStyle(
                              color: ZorvaTheme.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _insights?['message'] ?? 'Group Insights are exclusive to Flagship Subscribers.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: ZorvaTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildInsightMetricCard(
                            'Group Matches',
                            '${_insights?['total_group_matches'] ?? 0}',
                            Icons.sports_tennis_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInsightMetricCard(
                            'Active Members',
                            '${_insights?['active_members_count'] ?? 0}',
                            Icons.people_alt_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInsightMetricCard(
                      'Top Internal Rivalry',
                      _insights?['top_group_rivalry'] ?? 'None',
                      Icons.local_fire_department_rounded,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // MEMBER ROSTER SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MEMBER ROSTER 👥',
                        style: TextStyle(
                          color: ZorvaTheme.primaryGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '${_leaderboard.length} MEMBERS',
                        style: const TextStyle(
                          color: ZorvaTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_leaderboard.isEmpty)
                    const Text(
                      'No group members listed.',
                      style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 13),
                    )
                  else
                    Column(
                      children: _leaderboard.map((m) {
                        final name = m['name'] ?? 'Player';
                        final role = m['role'] ?? 'member';
                        final rating = m['rating'] ?? 1200;

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
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: ZorvaTheme.cardBg,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded, color: ZorvaTheme.primaryGold, size: 20),
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
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
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
