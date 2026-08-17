import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../../core/services/api_service.dart';
import 'group_detail_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class GroupsListScreen extends StatefulWidget {
  final String userId;
  final String? userCity;

  const GroupsListScreen({
    super.key,
    required this.userId,
    this.userCity,
  });

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  bool _loading = true;
  bool _isFlagship = false;
  String _userCity = 'Dallas';
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    if (widget.userCity != null && widget.userCity!.isNotEmpty) {
      _userCity = widget.userCity!;
    }
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _loading = true);
    final userGroups = await ApiService.getUserGroups(widget.userId);
    final subData = await ApiService.getSubscription(widget.userId);
    final isFlagshipUser = subData?['is_flagship'] == true;

    try {
      final profileRes = await ApiService.getUserProfile(widget.userId);
      if (profileRes != null && profileRes['city'] != null) {
        _userCity = profileRes['city'].toString();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _groups = userGroups;
        _isFlagship = isFlagshipUser;
        _loading = false;
      });
    }
  }

  void _showCreateGroupModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: _userCity);
    String groupType = 'community';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF14171A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: ZorvaTheme.primaryGold, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZorvaTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'CREATE GROUP 👥',
                style: TextStyle(
                  color: ZorvaTheme.primaryGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create a private group for your friends or club (Max 20 Members).',
                style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 18),

              // Group Type Selector (Only shown for Flagship Subscribers)
              if (_isFlagship) ...[
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => groupType = 'community'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: groupType == 'community' ? ZorvaTheme.primaryGold.withOpacity(0.15) : const Color(0xFF1C2024),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: groupType == 'community' ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'COMMUNITY 🎾',
                              style: TextStyle(
                                color: groupType == 'community' ? ZorvaTheme.primaryGold : ZorvaTheme.textMuted,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => groupType = 'flagship'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: groupType == 'flagship' ? ZorvaTheme.primaryGold.withOpacity(0.15) : const Color(0xFF1C2024),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: groupType == 'flagship' ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'FLAGSHIP ⚡',
                              style: TextStyle(
                                color: groupType == 'flagship' ? ZorvaTheme.primaryGold : ZorvaTheme.textMuted,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: ZorvaTheme.textPrimary, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  prefixIcon: Icon(Icons.people_alt_rounded, color: ZorvaTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                style: const TextStyle(color: ZorvaTheme.textPrimary, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_rounded, color: ZorvaTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: ZorvaTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.notes_rounded, color: ZorvaTheme.textMuted),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZorvaTheme.primaryGold,
                    foregroundColor: ZorvaTheme.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          setModalState(() => isSubmitting = true);

                          final res = await ApiService.createGroup(
                            name: name,
                            description: descCtrl.text.trim(),
                            city: cityCtrl.text.trim(),
                            groupType: groupType,
                            creatorId: widget.userId,
                          );

                          if (mounted) {
                            Navigator.pop(ctx);
                            if (res != null && res['error'] == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Community Group created successfully! 🎉'),
                                  backgroundColor: ZorvaTheme.primaryGold,
                                ),
                              );
                              _loadGroups();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res?['error'] ?? 'Failed to create group'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: ZorvaTheme.background)
                      : const Text(
                          'CREATE GROUP 🚀',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinGroupModal(BuildContext context) {
    final codeCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF14171A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: ZorvaTheme.primaryGold, width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZorvaTheme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'JOIN GROUP WITH INVITE CODE 🔑',
                style: TextStyle(
                  color: ZorvaTheme.primaryGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter the 6-character group invite code to join.',
                style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: ZorvaTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                decoration: const InputDecoration(
                  labelText: 'Invite Code (e.g. ZORVA8)',
                  prefixIcon: Icon(Icons.key_rounded, color: ZorvaTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZorvaTheme.primaryGold,
                    foregroundColor: ZorvaTheme.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim();
                          if (code.isEmpty) return;
                          setModalState(() => isSubmitting = true);

                          final res = await ApiService.joinGroup(
                            userId: widget.userId,
                            inviteCode: code,
                          );

                          if (mounted) {
                            Navigator.pop(ctx);
                            if (res != null && res['error'] == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['status'] == 'already_member'
                                      ? 'You are already a member of this group!'
                                      : 'Joined group successfully! 🎉'),
                                  backgroundColor: ZorvaTheme.primaryGold,
                                ),
                              );
                              _loadGroups();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res?['error'] ?? 'Failed to join group'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: ZorvaTheme.background)
                      : const Text(
                          'JOIN GROUP ⚡',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
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
      body: Stack(
        children: [
          // Background Aura
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
              onRefresh: _loadGroups,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'COMMUNITY GROUPS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: ZorvaTheme.primaryGold,
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showJoinGroupModal(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14171A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: ZorvaTheme.borderSubtle),
                                ),
                                child: const Text(
                                  'JOIN CODE',
                                  style: TextStyle(
                                    color: ZorvaTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showCreateGroupModal(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ZorvaTheme.primaryGold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: ZorvaTheme.primaryGold, width: 0.8),
                                ),
                                child: const Text(
                                  '+ CREATE',
                                  style: TextStyle(
                                    color: ZorvaTheme.primaryGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Groups List
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: ZorvaTheme.primaryGold)),
                      )
                    else if (_groups.isEmpty)
                      GestureDetector(
                        onTap: () => _showCreateGroupModal(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14171A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ZorvaTheme.borderSubtle),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: ZorvaTheme.primaryGold.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.group_add_rounded, color: ZorvaTheme.primaryGold, size: 36),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Community Groups Yet',
                                style: TextStyle(
                                  color: ZorvaTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Create a private group for your club or friends (Max 20 members) to compete on private leaderboards!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 12, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: ZorvaTheme.primaryGold,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '+ CREATE YOUR FIRST GROUP',
                                  style: TextStyle(
                                    color: ZorvaTheme.background,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _groups.length,
                        itemBuilder: (ctx, idx) {
                          final g = _groups[idx];
                          final name = g['name'] ?? 'Community Group';
                          final city = g['city'] ?? 'Dallas';
                          final sport = g['sport'] ?? 'Table Tennis';
                          final gType = g['group_type'] ?? 'community';
                          final isFlagship = gType == 'flagship';
                          final inviteCode = g['invite_code'] ?? '';
                          final memberCount = g['member_count'] ?? 1;
                          final maxMembers = g['max_members'] ?? 20;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GroupDetailScreen(
                                        group: g,
                                        userId: widget.userId,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14171A),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isFlagship ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
                                      width: isFlagship ? 1.2 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isFlagship ? ZorvaTheme.primaryGold.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isFlagship ? ZorvaTheme.primaryGold : Colors.blueAccent,
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  isFlagship ? 'FLAGSHIP ⚡' : 'COMMUNITY 🎾',
                                                  style: TextStyle(
                                                    color: isFlagship ? ZorvaTheme.primaryGold : Colors.blueAccent,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$sport · $city',
                                                style: const TextStyle(color: ZorvaTheme.textMuted, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$memberCount / $maxMembers Members',
                                              style: const TextStyle(
                                                color: Colors.greenAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: ZorvaTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'Code: ',
                                                style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 11),
                                              ),
                                              Text(
                                                inviteCode,
                                                style: const TextStyle(
                                                  color: ZorvaTheme.primaryGold,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: const [
                                              Text(
                                                'View Group',
                                                style: TextStyle(
                                                  color: ZorvaTheme.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(Icons.chevron_right_rounded, color: ZorvaTheme.textMuted, size: 18),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
