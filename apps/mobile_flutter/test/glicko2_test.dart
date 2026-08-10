import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/features/rating/domain/glicko2.dart';

void main() {
  group('Glicko-2 Engine Tests', () {
    test('Glickman Worked Example Paper Numerical Match', () {
      final player = const RatingState(rating: 1500, rd: 200, volatility: 0.06);

      final outcomes = [
        const MatchOutcome(opponent: RatingState(rating: 1400, rd: 30, volatility: 0.06), score: 1.0),
        const MatchOutcome(opponent: RatingState(rating: 1550, rd: 100, volatility: 0.06), score: 0.0),
        const MatchOutcome(opponent: RatingState(rating: 1700, rd: 300, volatility: 0.06), score: 0.0),
      ];

      final result = Glicko2Engine.updateRating(player, outcomes);

      expect(result.rating, closeTo(1464.06, 0.5));
      expect(result.rd, closeTo(151.52, 0.5));
      expect(result.volatility, closeTo(0.05999, 0.001));
    });

    test('Winner Rating Increases and Loser Decreases', () {
      final a = const RatingState(rating: 1500, rd: 100, volatility: 0.06);
      final b = const RatingState(rating: 1500, rd: 100, volatility: 0.06);

      final res = Glicko2Engine.applyMatchResult(playerA: a, playerB: b, aWon: true);

      expect(res['playerA']!.rating, greaterThan(1500.0));
      expect(res['playerB']!.rating, lessThan(1500.0));
    });
  });
}
