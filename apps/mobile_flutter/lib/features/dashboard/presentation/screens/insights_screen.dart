import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/zorva_theme.dart';
import '../../../../core/constants/supabase_constants.dart';

import '../../../../core/services/api_service.dart';

class InsightsScreen extends StatefulWidget {
  final String? userId;

  const InsightsScreen({super.key, this.userId});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _loading = true;
  List<double> _ratingHistoryPoints = [];
  int _currentRating = 1500;
  int _peakRating = 1500;
  int _winStreak = 0;
  int _bestWinStreak = 0;
  String _favoriteOpponent = '—';
  int _favOpponentWins = 0;
  String _toughestOpponent = '—';
  int _toughestOpponentLosses = 0;
  List<String> _formGuide = [];

  String get _effectiveUserId =>
      widget.userId ??
      Supabase.instance.client.auth.currentUser?.id ??
      SupabaseConstants.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadInsightsData();
  }

  Future<void> _loadInsightsData() async {
    setState(() => _loading = true);
    final userId = _effectiveUserId;

    // Try backend API server first
    final serverData = await ApiService.getPlayerInsights(userId);
    if (serverData != null) {
      if (mounted) {
        setState(() {
          _currentRating = (serverData['current_rating'] as num? ?? 1500).round();
          _peakRating = (serverData['peak_rating'] as num? ?? 1500).round();
          _winStreak = (serverData['win_streak'] as num? ?? 0).toInt();
          _bestWinStreak = (serverData['best_win_streak'] as num? ?? 0).toInt();
          _formGuide = List<String>.from(serverData['form_guide'] ?? []);
          _ratingHistoryPoints = List<double>.from((serverData['trajectory_points'] as List? ?? []).map((e) => (e as num).toDouble()));
          _loading = false;
        });
      }
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      // 1. Fetch Ratings for peak & current
      String? activeContextId;
      final ratingsRes = await supabase
          .from('player_context_ratings')
          .select('rating, context_id, rating_contexts(id, name, type)')
          .eq('user_id', userId);

      if (ratingsRes.isNotEmpty) {
        final List<Map<String, dynamic>> rList = List<Map<String, dynamic>>.from(ratingsRes);
        
        // Always prioritize Flagship rating card if user has Flagship membership
        final chosenCard = rList.firstWhere((r) {
          final ctx = r['rating_contexts'];
          if (ctx is Map && ctx['type'] == 'flagship') return true;
          if (ctx is List && ctx.isNotEmpty && ctx.first['type'] == 'flagship') return true;
          return false;
        }, orElse: () => rList.first);

        final num ratingNum = chosenCard['rating'] as num? ?? 1500;
        _currentRating = ratingNum.round();
        _peakRating = _currentRating;
        activeContextId = chosenCard['context_id'] as String?;
      }

      // 2. Fetch all verified matches for analytics
      final matchesRes = await supabase
          .from('matches')
          .select('*')
          .or('creator_id.eq.$userId,opponent_id.eq.$userId')
          .eq('status', 'confirmed')
          .order('logged_at', ascending: false);

      final matches = List<Map<String, dynamic>>.from(matchesRes);

      // Form Guide (Last 5)
      final List<String> form = [];
      int currentStreak = 0;
      bool streakActive = true;
      int maxStreak = 0;
      int tempStreak = 0;

      final Map<String, int> oppWins = {};
      final Map<String, int> oppLosses = {};

      for (var m in matches) {
        final isWin = m['winner_id'] == userId;
        final oppId = m['creator_id'] == userId ? m['opponent_id'] : m['creator_id'];

        if (form.length < 5) {
          form.add(isWin ? 'W' : 'L');
        }

        if (isWin) {
          if (streakActive) currentStreak++;
          tempStreak++;
          if (tempStreak > maxStreak) maxStreak = tempStreak;
          oppWins[oppId] = (oppWins[oppId] ?? 0) + 1;
        } else {
          streakActive = false;
          tempStreak = 0;
          oppLosses[oppId] = (oppLosses[oppId] ?? 0) + 1;
        }
      }

      _winStreak = currentStreak;
      _bestWinStreak = maxStreak;
      _formGuide = form.reversed.toList();

      // Find Favorite Opponent (Most Wins)
      if (oppWins.isNotEmpty) {
        final favId = oppWins.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        _favOpponentWins = oppWins[favId]!;

        final favProfile = await supabase
            .from('profiles')
            .select('full_name, username')
            .eq('id', favId)
            .maybeSingle();

        final rawName = favProfile?['full_name'] ?? favProfile?['username'];
        _favoriteOpponent = (rawName != null && rawName.toString().trim().isNotEmpty)
            ? rawName.toString().trim()
            : 'Player';
      }

      // Find Toughest Opponent (Most Losses)
      if (oppLosses.isNotEmpty) {
        final toughId = oppLosses.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        _toughestOpponentLosses = oppLosses[toughId]!;

        final toughProfile = await supabase
            .from('profiles')
            .select('full_name, username')
            .eq('id', toughId)
            .maybeSingle();

        final rawName = toughProfile?['full_name'] ?? toughProfile?['username'];
        _toughestOpponent = (rawName != null && rawName.toString().trim().isNotEmpty)
            ? rawName.toString().trim()
            : 'Player';
      }

      // 3. Exact Glicko-2 Trajectory from match_context_links
      final List<double> points = [];
      try {
        final userMatches = await supabase
            .from('matches')
            .select('id, creator_id, opponent_id')
            .or('creator_id.eq.$userId,opponent_id.eq.$userId')
            .eq('status', 'verified')
            .order('logged_at', ascending: true);

        final matchesList = List<Map<String, dynamic>>.from(userMatches);
        if (matchesList.isNotEmpty) {
          final matchIds = matchesList.map((m) => m['id'] as String).toList();
          var linksQuery = supabase
              .from('match_context_links')
              .select('*')
              .inFilter('match_id', matchIds);

          if (activeContextId != null) {
            linksQuery = linksQuery.eq('context_id', activeContextId);
          }

          final linksRes = await linksQuery.order('created_at', ascending: true);
          final links = List<Map<String, dynamic>>.from(linksRes);

          final Map<String, Map<String, dynamic>> matchMap = {
            for (var m in matchesList) m['id'] as String: m
          };

          for (var l in links) {
            final mId = l['match_id'] as String;
            final m = matchMap[mId];
            final isCreator = m?['creator_id'] == userId;

            if (points.isEmpty) {
              // Point 0: True Glicko-2 rating BEFORE Match 1
              final rBefore = isCreator
                  ? (l['p1_rating_before'] as num?)?.toDouble()
                  : (l['p2_rating_before'] as num?)?.toDouble();
              if (rBefore != null) points.add(rBefore);
            }

            // Point N: True Glicko-2 rating AFTER Match N
            final rAfter = isCreator
                ? (l['p1_rating_after'] as num?)?.toDouble()
                : (l['p2_rating_after'] as num?)?.toDouble();
            if (rAfter != null) points.add(rAfter);
          }
        }
      } catch (hErr) {
        debugPrint('Trajectory query note: $hErr');
      }

      if (points.isEmpty) {
        points.add(_currentRating.toDouble());
      }

      _ratingHistoryPoints = points;
      _peakRating = _ratingHistoryPoints.reduce((a, b) => a > b ? a : b).round();

    } catch (e) {
      debugPrint('Error loading insights: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<double> chartPts = List.from(_ratingHistoryPoints);
    final double curVal = _currentRating.toDouble();

    if (chartPts.isEmpty) {
      chartPts = [curVal];
    }

    final firstVal = chartPts.first;
    final lastVal = chartPts.last;
    final diff = (lastVal - firstVal).round();
    final isPositive = diff >= 0;

    return Scaffold(
      backgroundColor: ZorvaTheme.background,
      appBar: AppBar(
        title: const Text(
          'PLAYER INSIGHTS & ANALYTICS',
          style: TextStyle(
            fontSize: 13,
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
              onRefresh: _loadInsightsData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // RATING PROGRESS TRAJECTORY CHART CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ZorvaTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.show_chart_rounded, color: ZorvaTheme.primaryGold, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'GLICKO-2 TRAJECTORY',
                                  style: TextStyle(
                                    color: ZorvaTheme.primaryGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPositive
                                    ? Colors.greenAccent.withOpacity(0.15)
                                    : Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                              child: Text(
                                isPositive ? '📈 +$diff PTS' : '📉 $diff PTS',
                                style: TextStyle(
                                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _InsightsChartPainter(points: chartPts),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Baseline: ${firstVal.round()} PTS',
                              style: const TextStyle(color: ZorvaTheme.textMuted, fontSize: 11),
                            ),
                            Text(
                              'Current Rating: ${lastVal.round()} PTS',
                              style: const TextStyle(
                                color: ZorvaTheme.primaryGold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // RECENT FORM GUIDE & STREAK
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ZorvaTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RECENT FORM (LAST 5 MATCHES)',
                          style: TextStyle(
                            color: ZorvaTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: _formGuide.map((f) {
                                final isWin = f == 'W';
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isWin
                                        ? Colors.greenAccent.withOpacity(0.15)
                                        : Colors.redAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isWin ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      f,
                                      style: TextStyle(
                                        color: isWin ? Colors.greenAccent : Colors.redAccent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            Row(
                              children: [
                                const Text('🔥 STREAK: ', style: TextStyle(color: ZorvaTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('$_winStreak WINS', style: const TextStyle(color: ZorvaTheme.primaryGold, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // STAT CARDS GRID (Peak, Best Streak, Favorite Opponent, Nemesis)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.3,
                    children: [
                      _buildInsightCard(
                        title: 'PEAK RATING',
                        value: '$_peakRating PTS',
                        subtitle: 'Highest Glicko score',
                        icon: Icons.emoji_events_rounded,
                        color: ZorvaTheme.primaryGold,
                      ),
                      _buildInsightCard(
                        title: 'BEST STREAK',
                        value: '$_bestWinStreak WINS',
                        subtitle: 'Consecutive wins',
                        icon: Icons.local_fire_department_rounded,
                        color: Colors.orangeAccent,
                      ),
                      _buildInsightCard(
                        title: 'FAVORITE OPPONENT',
                        value: _favoriteOpponent,
                        subtitle: '$_favOpponentWins wins against',
                        icon: Icons.track_changes_rounded,
                        color: Colors.greenAccent,
                      ),
                      _buildInsightCard(
                        title: 'TOUGHEST RIVAL',
                        value: _toughestOpponent,
                        subtitle: '$_toughestOpponentLosses losses against',
                        icon: Icons.bolt_rounded,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14171A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZorvaTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ZorvaTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZorvaTheme.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsChartPainter extends CustomPainter {
  final List<double> points;

  _InsightsChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double minVal = (points.reduce((a, b) => a < b ? a : b) - 20).floorToDouble();
    final double maxVal = (points.reduce((a, b) => a > b ? a : b) + 20).ceilToDouble();
    final double range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    // Background horizontal grid lines & Y-axis scale labels
    final gridPaint = Paint()
      ..color = const Color(0xFF262B30)
      ..strokeWidth = 1.0;

    const int numGridLines = 3;
    final textStyle = TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold);

    for (int i = 0; i <= numGridLines; i++) {
      final yRatio = i / numGridLines;
      final yPos = size.height - (yRatio * (size.height - 30) + 15);
      final labelVal = (minVal + yRatio * range).round();

      canvas.drawLine(Offset(35, yPos), Offset(size.width, yPos), gridPaint);

      final textSpan = TextSpan(text: '$labelVal', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, yPos - 6));
    }

    final double chartLeft = 40.0;
    final double chartWidth = size.width - chartLeft;
    final double stepX = chartWidth / (points.length - 1 > 0 ? points.length - 1 : 1);

    final List<Offset> offsets = [];

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1 ? chartLeft + chartWidth / 2 : chartLeft + i * stepX;
      final normalizedY = (points[i] - minVal) / range;
      final y = size.height - (normalizedY * (size.height - 30) + 15);
      offsets.add(Offset(x, y));
    }

    if (offsets.length == 1) {
      canvas.drawCircle(offsets.first, 6, Paint()..color = ZorvaTheme.primaryGold);
      return;
    }

    final path = Path();
    final fillPath = Path();

    path.moveTo(offsets.first.dx, offsets.first.dy);
    fillPath.moveTo(offsets.first.dx, size.height - 15);
    fillPath.lineTo(offsets.first.dx, offsets.first.dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(offsets.last.dx, size.height - 15);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          ZorvaTheme.primaryGold.withOpacity(0.30),
          ZorvaTheme.primaryGold.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(chartLeft, 0, chartWidth, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = ZorvaTheme.primaryGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()..color = ZorvaTheme.primaryGold;
    final dotGlow = Paint()..color = Colors.amberAccent.withOpacity(0.6);

    for (int i = 0; i < offsets.length; i++) {
      final pt = offsets[i];
      canvas.drawCircle(pt, 5, dotGlow);
      canvas.drawCircle(pt, 3, dotPaint);

      // Point rating value label above dot
      final ptVal = points[i].round();
      final valSpan = TextSpan(
        text: '$ptVal',
        style: const TextStyle(
          color: ZorvaTheme.primaryGold,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      final valPainter = TextPainter(text: valSpan, textDirection: TextDirection.ltr);
      valPainter.layout();
      valPainter.paint(canvas, Offset(pt.dx - (valPainter.width / 2), pt.dy - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _InsightsChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
