import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/user_session.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../match_logger/presentation/screens/add_match_screen.dart';
import '../../../leaderboards/presentation/screens/leaderboards_screen.dart';
import '../../../onboarding/presentation/screens/welcome_screen.dart';
import '../../../rating/domain/glicko2.dart';
import 'profile_screen.dart';
import 'insights_screen.dart';
import '../../../../core/constants/subscription_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../groups/presentation/screens/group_detail_screen.dart';
import '../../../groups/presentation/screens/groups_list_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final String? userId;
  final String? displayName;
  final String? city;

  const HomeDashboardScreen({
    super.key,
    this.userId,
    this.displayName,
    this.city,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _currentIndex = 0;
  bool _loading = true;

  String _userPlanId = SubscriptionConstants.planCommunityTrial;
  String _userSubStatus = SubscriptionConstants.statusActive;

  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userRatings = [];
  int _selectedRatingIndex = 0;
  late final PageController _ratingPageController;
  List<Map<String, dynamic>> _recentMatches = [];
  List<Map<String, dynamic>> _pendingMatches = [];
  int _recentMatchesSubTabIndex = 0; // 0 = Verified, 1 = Pending
  List<double> _ratingHistoryPoints = [];
  int _totalVerifiedMatchesCount = 0;
  List<Map<String, dynamic>> _userGroups = [];

  String get _effectiveUserId =>
      widget.userId ??
      Supabase.instance.client.auth.currentUser?.id ??
      UserSession.userId ??
      SupabaseConstants.currentUserId;

  RealtimeChannel? _dashboardRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _ratingPageController = PageController();
    _loadDashboardData();
    _subscribeToRealtimeUpdates();
  }

  void _subscribeToRealtimeUpdates() {
    final supabase = Supabase.instance.client;
    final userId = _effectiveUserId;

    try {
      _dashboardRealtimeChannel = supabase
          .channel('public:dashboard_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'matches',
            callback: (payload) {
              debugPrint('⚡ Realtime Match Update: $payload');
              if (mounted) _loadDashboardData(silent: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'player_context_ratings',
            callback: (payload) {
              debugPrint('⚡ Realtime Rating Update: $payload');
              if (mounted) _loadDashboardData(silent: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime subscription note: $e');
    }
  }

  @override
  void dispose() {
    _dashboardRealtimeChannel?.unsubscribe();
    _ratingPageController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final supabase = Supabase.instance.client;
    final userId = _effectiveUserId;

    try {
      // 1. User Profile from Supabase `profiles` table
      try {
        final profileRes =
            await supabase.from('profiles').select().eq('id', userId).maybeSingle();
        if (profileRes != null) {
          _userProfile = profileRes;
        }
      } catch (pErr) {
        debugPrint('Profile fetch note: $pErr');
      }

      // 2. Ratings (Fetch both Community and Official Flagship contexts)
      try {
        final ratingRes = await supabase
            .from('player_context_ratings')
            .select('*, rating_contexts(id, name, type)')
            .eq('user_id', userId);
        _userRatings = List<Map<String, dynamic>>.from(ratingRes);
      } catch (rErr) {
        debugPrint('Ratings fetch note: $rErr');
      }

      // Sort so Official (flagship) is index 0 if present
      _userRatings.sort((a, b) {
        final typeA = a['rating_contexts']?['type'] ?? '';
        final typeB = b['rating_contexts']?['type'] ?? '';
        if (typeA == 'flagship') return -1;
        if (typeB == 'flagship') return 1;
        return 0;
      });

      // 3. Recent Verified Matches (Enriched with Opponent Name & City)
      try {
        final matchesRes = await supabase
            .from('matches')
            .select('*')
            .or('creator_id.eq.$userId,opponent_id.eq.$userId')
            .eq('status', 'verified')
            .order('logged_at', ascending: false)
            .limit(10);

        final List<Map<String, dynamic>> enrichedMatches = [];
        for (var m in matchesRes) {
          final isCreator = m['creator_id'] == userId;
          final opponentId = isCreator ? m['opponent_id'] : m['creator_id'];

          final matchId = m['id'];
          final opponentProfile = await supabase
              .from('profiles')
              .select('full_name, username, city')
              .eq('id', opponentId)
              .maybeSingle();

          bool isOfficial = false;
          try {
            final linkRes = await supabase
                .from('match_context_links')
                .select('context_id, rating_contexts(type)')
                .eq('match_id', matchId);

            if (linkRes != null && (linkRes as List).isNotEmpty) {
              for (var link in linkRes) {
                final ctx = link['rating_contexts'];
                if (ctx != null) {
                  final type = ctx is Map
                      ? ctx['type']
                      : (ctx is List && (ctx as List).isNotEmpty ? ctx[0]['type'] : null);
                  if (type == 'flagship') {
                    isOfficial = true;
                    break;
                  }
                }
              }
            }
          } catch (lErr) {
            debugPrint('match_context_links lookup note: $lErr');
          }

          final map = Map<String, dynamic>.from(m);
          final rawOppName = opponentProfile?['full_name'] ?? opponentProfile?['username'];
          map['opponent_name'] = (rawOppName != null && rawOppName.toString().trim().isNotEmpty)
              ? rawOppName.toString().trim()
              : 'Player';
          map['opponent_city'] = opponentProfile?['city'] ?? '';
          map['is_official'] = isOfficial;
          enrichedMatches.add(map);
        }
        _recentMatches = enrichedMatches;

        // Fetch uncapped total verified matches count for trial tracking
        final allVerifiedRes = await supabase
            .from('matches')
            .select('id')
            .or('creator_id.eq.$userId,opponent_id.eq.$userId')
            .eq('status', 'verified');
        _totalVerifiedMatchesCount = allVerifiedRes.length;
      } catch (mErr) {
        debugPrint('Recent matches fetch note: $mErr');
      }

      // 4. Pending Matches (Both incoming requiring approval & outgoing waiting for opponent)
      try {
        final pendingRes = await supabase
            .from('matches')
            .select('*')
            .or('creator_id.eq.$userId,opponent_id.eq.$userId')
            .eq('status', 'pending')
            .order('logged_at', ascending: false);

        final List<Map<String, dynamic>> enrichedPending = [];
        for (var pm in pendingRes) {
          final isCreator = pm['creator_id'] == userId;
          final otherId = isCreator ? pm['opponent_id'] : pm['creator_id'];

          final otherProfile = await supabase
              .from('profiles')
              .select('full_name, username, city')
              .eq('id', otherId)
              .maybeSingle();

          final map = Map<String, dynamic>.from(pm);
          final rawName = otherProfile?['full_name'] ?? otherProfile?['username'];
          map['other_name'] = (rawName != null && rawName.toString().trim().isNotEmpty)
              ? rawName.toString().trim()
              : 'Player';
          map['other_city'] = otherProfile?['city'] ?? '';
          map['creator_name'] = isCreator ? 'You' : map['other_name'];
          map['is_incoming'] = !isCreator; // Needs current user approval
          enrichedPending.add(map);
        }
        _pendingMatches = enrichedPending;
      } catch (pErr) {
        debugPrint('Pending matches fetch note: $pErr');
      }

      // 5. Fetch Subscription Info from premium_subscriptions
      try {
        final serverSub = await ApiService.getSubscription(userId);
        if (serverSub != null) {
          _userPlanId = serverSub['plan_id'] ?? SubscriptionConstants.planCommunityTrial;
          _userSubStatus = serverSub['status'] ?? SubscriptionConstants.statusActive;
          if (serverSub['verified_matches_count'] != null) {
            _totalVerifiedMatchesCount = (serverSub['verified_matches_count'] as num).toInt();
          }
        } else {
          final subRes = await supabase
              .from('premium_subscriptions')
              .select('plan_id, status')
              .eq('user_id', userId)
              .maybeSingle();

          if (subRes != null) {
            _userPlanId = subRes['plan_id'] ?? SubscriptionConstants.planCommunityTrial;
            _userSubStatus = subRes['status'] ?? SubscriptionConstants.statusActive;
          }
        }
      } catch (sErr) {
        debugPrint('Subscription fetch note: $sErr');
      }

      // 6. Fetch User Groups
      try {
        _userGroups = await ApiService.getUserGroups(userId);
      } catch (gErr) {
        debugPrint('User groups fetch note: $gErr');
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFlagshipUpgradeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Color(0xFF14171A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: ZorvaTheme.primaryGold, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ZorvaTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZorvaTheme.primaryGold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: ZorvaTheme.primaryGold, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'YOUR 10-MATCH FREE TRIAL HAS ENDED',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ZorvaTheme.primaryGold,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upgrade to Flagship Membership to keep tracking your Glicko-2 progress trajectory curves, head-to-head rivalries, and official city leaderboards.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ZorvaTheme.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildUpgradeFeatureRow(Icons.show_chart_rounded, 'Full Glicko-2 Rating Trajectory Curves'),
            const SizedBox(height: 12),
            _buildUpgradeFeatureRow(Icons.emoji_events_rounded, 'Official City Rankings & Global Leaderboards'),
            const SizedBox(height: 12),
            _buildUpgradeFeatureRow(Icons.military_tech_rounded, 'Win Streaks & Rivalry Head-to-Head Stats'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZorvaTheme.primaryGold,
                  foregroundColor: ZorvaTheme.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: ZorvaTheme.primaryGold,
                      content: Text('⚡ Upgrade to Flagship coming soon!', style: TextStyle(color: ZorvaTheme.background, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
                child: const Text(
                  'UPGRADE TO FLAGSHIP ⚡',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeFeatureRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: ZorvaTheme.primaryGold, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context) {
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

  Future<void> _declineMatch(String matchId) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('matches').update({
        'status': 'rejected',
      }).eq('id', matchId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Match approval request declined.'),
          ),
        );
      }
      _loadDashboardData(silent: true);
    } catch (e) {
      debugPrint('Error declining match: $e');
    }
  }

  Future<void> _quickApproveMatch(String matchId) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id ?? _effectiveUserId;

    try {
      // 1. Record user confirmation
      await supabase.from('match_confirmations').upsert({
        'match_id': matchId,
        'user_id': userId,
        'action': 'confirmed',
      }, onConflict: 'match_id,user_id');

      // 2. Fetch match info
      final matchRes =
          await supabase.from('matches').select().eq('id', matchId).maybeSingle();

      if (matchRes != null) {
        final String creatorId = matchRes['creator_id'];
        final String opponentId = matchRes['opponent_id'];
        final String winnerId = matchRes['winner_id'] ?? creatorId;
        final bool creatorWon = winnerId == creatorId;

        // 3. Mark match as verified
        await supabase.from('matches').update({
          'status': 'verified',
        }).eq('id', matchId);

        // 4. Multi-Context Glicko-2 Update: Fetch all rating contexts shared by both players
        final creatorContexts = await supabase
            .from('player_context_ratings')
            .select('context_id')
            .eq('user_id', creatorId);

        final creatorContextIds =
            (creatorContexts as List).map((c) => c['context_id'] as String).toSet();

        final opponentContexts = await supabase
            .from('player_context_ratings')
            .select('context_id')
            .eq('user_id', opponentId);

        final opponentContextIds =
            (opponentContexts as List).map((c) => c['context_id'] as String).toSet();

        // Target all shared contexts, or default to Community context
        Set<String> sharedContextIds = creatorContextIds.intersection(opponentContextIds);

        final defaultCommunityContext = await supabase
            .from('rating_contexts')
            .select('id')
            .eq('type', 'community')
            .maybeSingle();

        if (defaultCommunityContext != null) {
          sharedContextIds.add(defaultCommunityContext['id'] as String);
        }

        // Loop over EVERY shared rating context (Community, Flagship, Age Tiers, Leagues)
        for (final String cId in sharedContextIds) {
          // Fetch Creator PCR for this context
          final creatorRatingRes = await supabase
              .from('player_context_ratings')
              .select()
              .eq('user_id', creatorId)
              .eq('context_id', cId)
              .maybeSingle();

          // Fetch Opponent PCR for this context
          final opponentRatingRes = await supabase
              .from('player_context_ratings')
              .select()
              .eq('user_id', opponentId)
              .eq('context_id', cId)
              .maybeSingle();

          final creatorState = RatingState(
            rating: (creatorRatingRes?['rating'] as num?)?.toDouble() ?? 1500.0,
            rd: (creatorRatingRes?['rd'] as num?)?.toDouble() ?? 350.0,
            volatility: (creatorRatingRes?['volatility'] as num?)?.toDouble() ?? 0.06,
          );

          final opponentState = RatingState(
            rating: (opponentRatingRes?['rating'] as num?)?.toDouble() ?? 1500.0,
            rd: (opponentRatingRes?['rd'] as num?)?.toDouble() ?? 350.0,
            volatility: (opponentRatingRes?['volatility'] as num?)?.toDouble() ?? 0.06,
          );

          // Calculate Glicko-2 engine outcome
          final glickoResult = Glicko2Engine.applyMatchResult(
            playerA: creatorState,
            playerB: opponentState,
            aWon: creatorWon,
          );

          final newCreatorState = glickoResult['playerA']!;
          final newOpponentState = glickoResult['playerB']!;

          final cWins = (creatorRatingRes?['wins'] as int? ?? 0) + (creatorWon ? 1 : 0);
          final cLosses = (creatorRatingRes?['losses'] as int? ?? 0) + (creatorWon ? 0 : 1);
          final cPlayed = (creatorRatingRes?['matches_played'] as int? ?? 0) + 1;

          final oWins = (opponentRatingRes?['wins'] as int? ?? 0) + (creatorWon ? 0 : 1);
          final oLosses = (opponentRatingRes?['losses'] as int? ?? 0) + (creatorWon ? 1 : 0);
          final oPlayed = (opponentRatingRes?['matches_played'] as int? ?? 0) + 1;

          // Upsert Creator PCR for this context
          await supabase.from('player_context_ratings').upsert({
            'user_id': creatorId,
            'context_id': cId,
            'rating': newCreatorState.rating,
            'rd': newCreatorState.rd,
            'volatility': newCreatorState.volatility,
            'wins': cWins,
            'losses': cLosses,
            'matches_played': cPlayed,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,context_id');

          // Upsert Opponent PCR for this context
          await supabase.from('player_context_ratings').upsert({
            'user_id': opponentId,
            'context_id': cId,
            'rating': newOpponentState.rating,
            'rd': newOpponentState.rd,
            'volatility': newOpponentState.volatility,
            'wins': oWins,
            'losses': oLosses,
            'matches_played': oPlayed,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,context_id');

          // Audit Log into match_context_links
          try {
            await supabase.from('match_context_links').upsert({
              'match_id': matchId,
              'context_id': cId,
              'p1_rating_before': creatorState.rating,
              'p1_rating_after': newCreatorState.rating,
              'p2_rating_before': opponentState.rating,
              'p2_rating_after': newOpponentState.rating,
              'created_at': DateTime.now().toIso8601String(),
            }, onConflict: 'match_id,context_id');
          } catch (mclErr) {
            debugPrint('match_context_links note: $mclErr');
          }
        }

        // STEP 2: Check and expire trial if verified matches > 10
        await _checkAndUpdateTrialExpiration(creatorId);
        await _checkAndUpdateTrialExpiration(opponentId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZorvaTheme.primaryGold,
            content: Text(
              '⚡ Match Verified! Glicko-2 Ratings Updated.',
              style: TextStyle(color: ZorvaTheme.background, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error approving match: $e'),
          ),
        );
      }
    }
  }

  Future<void> _checkAndUpdateTrialExpiration(String pId) async {
    try {
      final supabase = Supabase.instance.client;
      final sub = await supabase
          .from('premium_subscriptions')
          .select('plan_id, status')
          .eq('user_id', pId)
          .maybeSingle();

      if (sub != null &&
          sub['plan_id'] == SubscriptionConstants.planCommunityTrial &&
          sub['status'] == SubscriptionConstants.statusActive) {
        
        final mRes = await supabase
            .from('matches')
            .select('id')
            .or('creator_id.eq.$pId,opponent_id.eq.$pId')
            .eq('status', 'verified');

        final int totalVerified = mRes.length;
        if (totalVerified > SubscriptionConstants.trialMaxMatches) {
          await supabase
              .from('premium_subscriptions')
              .update({'status': SubscriptionConstants.statusExpired})
              .eq('user_id', pId)
              .eq('plan_id', SubscriptionConstants.planCommunityTrial);
          debugPrint('Community trial expired for user $pId (Played $totalVerified matches)');
        }
      }
    } catch (e) {
      debugPrint('Trial check error: $e');
    }
  }

  void _showRatingsFaqModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14171A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(28),
          child: ListView(
            shrinkWrap: true,
            children: const [
              Text(
                'HOW ZORVA RATINGS WORK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: ZorvaTheme.primaryGold,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 20),
              Text(
                '1. Dynamic Skill Calibration',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ZorvaTheme.textPrimary,
                    fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Zorva uses a state-of-the-art competitive Glicko-2 engine to dynamically calculate skill progression based on opponent strength and match outcomes.',
                style: TextStyle(color: ZorvaTheme.textSecondary, fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '2. Dual Rating System',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ZorvaTheme.textPrimary,
                    fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                '• Community Rating: 100% free forever for all players to track every game.\n• Official Zorva Rating: Powers city leaderboards and official rankings.',
                style: TextStyle(color: ZorvaTheme.textSecondary, fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '3. Verified Match Integrity',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ZorvaTheme.textPrimary,
                    fontSize: 14),
              ),
              Text(
                'Ratings update after both players confirm the match result, ensuring 100% fair and trusted rankings.',
                style: const TextStyle(color: ZorvaTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateGroupModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: widget.city ?? 'Dallas');
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
                'CREATE COMMUNITY GROUP 👥',
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
                            creatorId: _effectiveUserId,
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
                              _loadDashboardData();
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
                            userId: _effectiveUserId,
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
                              _loadDashboardData();
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
    final List<Widget> pages = [
      _buildHomeContent(),
      const LeaderboardsScreen(),
      GroupsListScreen(
        userId: _effectiveUserId,
        userCity: widget.city,
      ),
    ];

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      body: pages[_currentIndex % pages.length],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF14171A),
          border: Border(top: BorderSide(color: ZorvaTheme.borderSubtle, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex % pages.length,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: ZorvaTheme.primaryGold,
          unselectedItemColor: ZorvaTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (idx) => setState(() => _currentIndex = idx),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield, color: ZorvaTheme.primaryGold),
              label: 'Passport',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events, color: ZorvaTheme.primaryGold),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups, color: ZorvaTheme.primaryGold),
              label: 'Groups',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ZorvaTheme.primaryGold),
      );
    }

    final currentRatingObj = _userRatings.isNotEmpty
        ? _userRatings[_selectedRatingIndex % _userRatings.length]
        : null;

    final ratingVal = currentRatingObj != null
        ? (currentRatingObj['rating'] as num).round()
        : ((_userProfile?['glicko_rating'] as num?)?.round() ?? UserSession.glickoRating.round());

    final wins = currentRatingObj?['wins'] ?? 0;
    final losses = currentRatingObj?['losses'] ?? 0;
    final matchesPlayed = currentRatingObj?['matches_played'] ?? (wins + losses);
    final winRate =
        matchesPlayed > 0 ? ((wins / matchesPlayed) * 100).round() : 0;
    final contextType =
        currentRatingObj?['rating_contexts']?['type'] ?? 'community';
    final isOfficial = contextType == 'flagship';

    final city = (_userProfile?['city'] != null && _userProfile!['city'].toString().isNotEmpty)
        ? _userProfile!['city'].toString()
        : widget.city ?? UserSession.city;

    final rawName = _userProfile?['full_name'] ?? _userProfile?['username'] ?? widget.displayName ?? UserSession.fullName;
    final name = (rawName != null && rawName.toString().trim().isNotEmpty)
        ? rawName.toString().trim()
        : (UserSession.fullName.isNotEmpty ? UserSession.fullName : 'Founding Player');

    return Stack(
      children: [
        // Rich Golden Ambient Aura Mesh
        Positioned(
          top: -80,
          left: MediaQuery.of(context).size.width * 0.05,
          width: MediaQuery.of(context).size.width * 0.9,
          height: 420,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: ZorvaTheme.goldGlowAura,
            ),
          ),
        ),

        RefreshIndicator(
          color: ZorvaTheme.primaryGold,
          onRefresh: _loadDashboardData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 110),
            children: [
              // Minimalist Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'ZORVA',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: ZorvaTheme.primaryGold,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'SPORTS PASSPORT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ZorvaTheme.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: _effectiveUserId),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x331C2024),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ZorvaTheme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: ZorvaTheme.primaryGold,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                  style: const TextStyle(
                                    color: ZorvaTheme.background,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: ZorvaTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: ZorvaTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: ZorvaTheme.textSecondary, size: 20),
                        tooltip: 'Sign Out',
                        onPressed: () => _showSignOutDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Enriched Pending Match Approval Cards (ONLY shown to recipient/opponent)
              for (var m in _pendingMatches.where((p) => p['is_incoming'] == true)) ...[
                Builder(builder: (context) {
                  final creatorName = m['creator_name'] ?? 'Opponent';
                  final cScore = m['creator_score'] ?? 0;
                  final oScore = m['opponent_score'] ?? 0;
                  final winnerId = m['winner_id'];
                  final creatorWon = winnerId == m['creator_id'];

                  final resultSummary = creatorWon
                      ? '$creatorName won ($cScore - $oScore)'
                      : 'You won ($oScore - $cScore)';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x22D4AF37),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ZorvaTheme.primaryGold),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.circle, color: Colors.amberAccent, size: 8),
                                SizedBox(width: 8),
                                Text(
                                  'MATCH APPROVAL REQUEST',
                                  style: TextStyle(
                                    color: ZorvaTheme.primaryGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Score: $cScore - $oScore',
                              style: const TextStyle(
                                color: ZorvaTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Logged by: $creatorName',
                          style: const TextStyle(
                            color: ZorvaTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Claimed Result: $resultSummary',
                          style: const TextStyle(
                            color: ZorvaTheme.primaryGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  foregroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _declineMatch(m['id']),
                                child: const Text(
                                  'DECLINE',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ZorvaTheme.primaryGold,
                                  foregroundColor: ZorvaTheme.background,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _quickApproveMatch(m['id']),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bolt, color: ZorvaTheme.background, size: 18),
                                    SizedBox(width: 4),
                                    Text(
                                      'APPROVE & RATIFY',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // SWIPEABLE RATING CARDS
              if (_userRatings.isEmpty)
                _buildRatingCard(
                  contextName: 'COMMUNITY',
                  contextType: 'community',
                  ratingVal: ratingVal,
                  wins: wins,
                  losses: losses,
                  matchesPlayed: matchesPlayed,
                  winRate: winRate,
                  city: city,
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 230,
                      child: PageView.builder(
                        controller: _ratingPageController,
                        itemCount: _userRatings.length,
                        onPageChanged: (idx) => setState(() => _selectedRatingIndex = idx),
                        itemBuilder: (context, idx) {
                          final r = _userRatings[idx];
                          final rType = r['rating_contexts']?['type'] ?? 'community';
                          final rName = r['rating_contexts']?['name'] ?? 'Community';
                          final rVal = (r['rating'] as num?)?.round() ?? 1500;
                          final rWins = r['wins'] ?? 0;
                          final rLosses = r['losses'] ?? 0;
                          final rPlayed = r['matches_played'] ?? (rWins + rLosses);
                          final rWinRate = rPlayed > 0 ? ((rWins / rPlayed) * 100).round() : 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _buildRatingCard(
                              contextName: rName.toString().toUpperCase(),
                              contextType: rType,
                              ratingVal: rVal,
                              wins: rWins,
                              losses: rLosses,
                              matchesPlayed: rPlayed,
                              winRate: rWinRate,
                              city: city,
                            ),
                          );
                        },
                      ),
                    ),
                    if (_userRatings.length > 1) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_userRatings.length, (idx) {
                          final isActive = idx == _selectedRatingIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? ZorvaTheme.primaryGold : ZorvaTheme.borderSubtle,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 24),

              // INSIGHTS & ANALYTICS BUTTON CARD (With 10-Match Trial & Lock System)
              InkWell(
                onTap: () {
                  final bool isFlagship = SubscriptionConstants.isFlagshipMember(_userPlanId, _userSubStatus);
                  final bool isTrialActive = SubscriptionConstants.isTrialActive(_userPlanId, _userSubStatus, _totalVerifiedMatchesCount);

                  if (isFlagship || isTrialActive) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InsightsScreen(userId: _effectiveUserId),
                      ),
                    );
                  } else {
                    _showFlagshipUpgradeModal(context);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ZorvaTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            SubscriptionConstants.isFlagshipMember(_userPlanId, _userSubStatus) ||
                                    SubscriptionConstants.isTrialActive(_userPlanId, _userSubStatus, _totalVerifiedMatchesCount)
                                ? Icons.insights_rounded
                                : Icons.lock_rounded,
                            color: ZorvaTheme.primaryGold,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                SubscriptionConstants.isFlagshipMember(_userPlanId, _userSubStatus)
                                    ? 'PLAYER INSIGHTS & ANALYTICS'
                                    : SubscriptionConstants.isTrialActive(_userPlanId, _userSubStatus, _totalVerifiedMatchesCount)
                                        ? '✨ FLAGSHIP TRIAL (${(SubscriptionConstants.trialMaxMatches - _totalVerifiedMatchesCount).clamp(0, 10)} / 10 LEFT)'
                                        : '🔒 UNLOCK PLAYER INSIGHTS & ANALYTICS',
                                style: const TextStyle(
                                  color: ZorvaTheme.primaryGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                SubscriptionConstants.isFlagshipMember(_userPlanId, _userSubStatus)
                                    ? 'Rating Trajectory, Streaks & Rivalries'
                                    : SubscriptionConstants.isTrialActive(_userPlanId, _userSubStatus, _totalVerifiedMatchesCount)
                                        ? 'Enjoy your 10-match Insights preview'
                                        : 'Upgrade to Flagship to view trajectory graphs',
                                style: const TextStyle(
                                  color: ZorvaTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: ZorvaTheme.primaryGold, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Matches Section Header with Verified & Pending Sub-Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT MATCHES',
                    style: TextStyle(
                      color: ZorvaTheme.primaryGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ZorvaTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _recentMatchesSubTabIndex = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _recentMatchesSubTabIndex == 0
                                  ? ZorvaTheme.primaryGold
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'VERIFIED (${_recentMatches.length})',
                              style: TextStyle(
                                color: _recentMatchesSubTabIndex == 0
                                    ? ZorvaTheme.background
                                    : ZorvaTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _recentMatchesSubTabIndex = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _recentMatchesSubTabIndex == 1
                                  ? ZorvaTheme.primaryGold
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'PENDING (${_pendingMatches.length})',
                                  style: TextStyle(
                                    color: _recentMatchesSubTabIndex == 1
                                        ? ZorvaTheme.background
                                        : ZorvaTheme.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (_pendingMatches.any((p) => p['is_incoming'] == true)) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.amberAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // SUB-TAB CONTENT: Verified Matches
              if (_recentMatchesSubTabIndex == 0) ...[
                if (_recentMatches.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ZorvaTheme.borderSubtle),
                    ),
                    child: const Center(
                      child: Text(
                        'No verified matches yet. Log a game below!',
                        style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 215,
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: _recentMatches.map((m) {
                        final userId = _effectiveUserId;
                        final isCreator = m['creator_id'] == userId;
                        final isWin = m['winner_id'] == userId;
                        final oppName = m['opponent_name'] ?? 'Opponent';
                        final oppCity = m['opponent_city'] ?? '';
                        final isOfficial = m['is_official'] == true ||
                            m['match_type'] == 'flagship' ||
                            m['context_type'] == 'flagship';

                        final cScore = m['creator_score'] ?? 0;
                        final oScore = m['opponent_score'] ?? 0;
                        final userScore = isCreator ? cScore : oScore;
                        final oppScore = isCreator ? oScore : cScore;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14171A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ZorvaTheme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isWin
                                      ? Colors.greenAccent.withOpacity(0.15)
                                      : Colors.redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isWin ? Colors.greenAccent : Colors.redAccent,
                                  ),
                                ),
                                child: Text(
                                  isWin ? 'WIN' : 'LOSS',
                                  style: TextStyle(
                                    color: isWin ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
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
                                          'vs $oppName',
                                          style: const TextStyle(
                                            color: ZorvaTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (oppCity.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '($oppCity)',
                                            style: const TextStyle(
                                              color: ZorvaTheme.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isOfficial
                                                ? ZorvaTheme.primaryGold.withOpacity(0.15)
                                                : Colors.tealAccent.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isOfficial ? ZorvaTheme.primaryGold : Colors.tealAccent,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            isOfficial ? 'OFFICIAL ⚡' : 'COMMUNITY 🎾',
                                            style: TextStyle(
                                              color: isOfficial ? ZorvaTheme.primaryGold : Colors.tealAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Score: $userScore - $oppScore · Table Tennis',
                                      style: const TextStyle(
                                        color: ZorvaTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ]
              // SUB-TAB CONTENT: Pending Matches
              else ...[
                if (_pendingMatches.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ZorvaTheme.borderSubtle),
                    ),
                    child: const Center(
                      child: Text(
                        'No pending match confirmations right now.',
                        style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 215,
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: _pendingMatches.map((m) {
                        final isIncoming = m['is_incoming'] == true;
                        final otherName = m['other_name'] ?? 'Player';
                        final cScore = m['creator_score'] ?? 0;
                        final oScore = m['opponent_score'] ?? 0;
                        final winnerId = m['winner_id'];
                        final creatorWon = winnerId == m['creator_id'];

                        if (isIncoming) {
                          final resultSummary = creatorWon
                              ? '$otherName won ($cScore - $oScore)'
                              : 'You won ($oScore - $cScore)';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0x22D4AF37),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ZorvaTheme.primaryGold),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.circle, color: Colors.amberAccent, size: 8),
                                        SizedBox(width: 8),
                                        Text(
                                          'APPROVAL NEEDED',
                                          style: TextStyle(
                                            color: ZorvaTheme.primaryGold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Score: $cScore - $oScore',
                                      style: const TextStyle(
                                        color: ZorvaTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Logged by $otherName · $resultSummary',
                                  style: const TextStyle(
                                    color: ZorvaTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.redAccent),
                                          foregroundColor: Colors.redAccent,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () => _declineMatch(m['id']),
                                        child: const Text('DECLINE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ZorvaTheme.primaryGold,
                                          foregroundColor: ZorvaTheme.background,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () => _quickApproveMatch(m['id']),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.bolt, color: ZorvaTheme.background, size: 16),
                                            SizedBox(width: 4),
                                            Text('APPROVE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Outgoing match waiting for opponent
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14171A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ZorvaTheme.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amberAccent),
                                  ),
                                  child: const Text(
                                    'WAITING',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'vs $otherName',
                                        style: const TextStyle(
                                          color: ZorvaTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Score: $cScore - $oScore · Waiting for $otherName to confirm',
                                        style: const TextStyle(
                                          color: ZorvaTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.access_time, color: Colors.amberAccent, size: 18),
                              ],
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),

        // Glowing Floating Metallic Quick Log Button
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55D4AF37),
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
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddMatchScreen()),
                  );
                  _loadDashboardData();
                },
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt, color: ZorvaTheme.background, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'QUICK LOG MATCH (< 10S)',
                        style: TextStyle(
                          color: ZorvaTheme.background,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassStatPill(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF14171A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ZorvaTheme.borderSubtle),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: ZorvaTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard({
    required String contextName,
    required String contextType,
    required int ratingVal,
    required int wins,
    required int losses,
    required int matchesPlayed,
    required int winRate,
    required String city,
  }) {
    final isOfficial = contextType == 'flagship';
    final isCityCtx = contextType == 'city';
    final isLeague = contextType == 'league';

    final Color accentColor = isOfficial
        ? ZorvaTheme.primaryGold
        : isCityCtx
            ? const Color(0xFF5B9BD5)
            : isLeague
                ? const Color(0xFFAB7EE8)
                : const Color(0xFF9CA3AF); // community = silver

    final String emoji = isOfficial
        ? '🏆'
        : isCityCtx
            ? '🏙️'
            : isLeague
                ? '⚡'
                : '🌱';

    final Color glowColor = accentColor.withOpacity(0.2);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1914), Color(0xFF0F0E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor, width: isOfficial ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 24, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Context label + city
              Row(
                children: [
                  Text(
                    '$emoji $contextName',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      '📍 $city',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'TABLE TENNIS',
                style: const TextStyle(
                  color: ZorvaTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big rating number
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isOfficial
                      ? const [Color(0xFFFFF0B3), Color(0xFFE5C158), Color(0xFFB88E1C)]
                      : [accentColor.withOpacity(0.9), accentColor, accentColor.withOpacity(0.7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: Text(
                  '$ratingVal',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'PTS',
                style: TextStyle(
                  color: accentColor.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stat pills
          Row(
            children: [
              _buildGlassStatPill('$matchesPlayed', 'MATCHES', ZorvaTheme.textPrimary),
              const SizedBox(width: 8),
              _buildGlassStatPill('$wins', 'WINS', Colors.greenAccent),
              const SizedBox(width: 8),
              _buildGlassStatPill('$losses', 'LOSSES', Colors.redAccent),
              const SizedBox(width: 8),
              _buildGlassStatPill('$winRate%', 'WIN RATE', accentColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingChartPainter extends CustomPainter {
  final List<double> points;

  _RatingChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double minVal = points.reduce((a, b) => a < b ? a : b) - 10;
    final double maxVal = points.reduce((a, b) => a > b ? a : b) + 10;
    final double range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    final path = Path();
    final fillPath = Path();

    final List<Offset> offsets = [];
    final double stepX = size.width / (points.length - 1 > 0 ? points.length - 1 : 1);

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1 ? size.width / 2 : i * stepX;
      final normalizedY = (points[i] - minVal) / range;
      final y = size.height - (normalizedY * (size.height - 20) + 10);
      offsets.add(Offset(x, y));
    }

    if (offsets.length == 1) {
      canvas.drawCircle(offsets.first, 6, Paint()..color = ZorvaTheme.primaryGold);
      return;
    }

    path.moveTo(offsets.first.dx, offsets.first.dy);
    fillPath.moveTo(offsets.first.dx, size.height);
    fillPath.lineTo(offsets.first.dx, offsets.first.dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(offsets.last.dx, size.height);
    fillPath.close();

    // Fill Gradient under curve
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          ZorvaTheme.primaryGold.withOpacity(0.35),
          ZorvaTheme.primaryGold.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Gold Stroke Line
    final strokePaint = Paint()
      ..color = ZorvaTheme.primaryGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Glowing Gold Dots on Data Points
    final dotPaint = Paint()..color = ZorvaTheme.primaryGold;
    final dotGlow = Paint()..color = Colors.amberAccent.withOpacity(0.6);

    for (final pt in offsets) {
      canvas.drawCircle(pt, 5, dotGlow);
      canvas.drawCircle(pt, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RatingChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
