import 'dart:math' as math;

/// Immutable state for a player's Glicko-2 rating.
class RatingState {
  final double rating;
  final double rd;
  final double volatility;

  const RatingState({
    required this.rating,
    required this.rd,
    required this.volatility,
  });

  static const defaultState = RatingState(
    rating: 1500.0,
    rd: 350.0,
    volatility: 0.06,
  );
}

/// Represents the outcome of a match against a single opponent.
class MatchOutcome {
  final RatingState opponent;
  final double score; // 1.0 = win, 0.5 = draw, 0.0 = loss

  const MatchOutcome({
    required this.opponent,
    required this.score,
  });
}

/// Core Glicko-2 mathematical calculations (Glickman, 1999).
class Glicko2Engine {
  static const double _scale = 173.7178;
  static const double _tau = 0.5;
  static const double _epsilon = 0.000001;

  static double _g(double phi) {
    return 1.0 / math.sqrt(1.0 + 3.0 * phi * phi / (math.pi * math.pi));
  }

  static double _calcE(double mu, double muJ, double phiJ) {
    return 1.0 / (1.0 + math.exp(-_g(phiJ) * (mu - muJ)));
  }

  /// Calculates updated rating state after a period of matches.
  static RatingState updateRating(RatingState player, List<MatchOutcome> outcomes) {
    if (outcomes.isEmpty) {
      throw ArgumentError('At least one match outcome is required.');
    }

    final double mu = (player.rating - 1500.0) / _scale;
    final double phi = player.rd / _scale;
    final double sigma = player.volatility;

    // Step 3: Compute v (variance)
    double vInv = 0.0;
    double deltaSum = 0.0;

    for (final outcome in outcomes) {
      final double muJ = (outcome.opponent.rating - 1500.0) / _scale;
      final double phiJ = outcome.opponent.rd / _scale;
      final double gPhiJ = _g(phiJ);
      final double eVal = _calcE(mu, muJ, phiJ);

      vInv += gPhiJ * gPhiJ * eVal * (1.0 - eVal);
      deltaSum += gPhiJ * (outcome.score - eVal);
    }

    final double v = 1.0 / vInv;
    final double delta = v * deltaSum;

    // Step 5: Determine new volatility sigma' using Illinois algorithm
    final double a = math.log(sigma * sigma);

    double f(double x) {
      final double expX = math.exp(x);
      final double phi2 = phi * phi;
      final double num = expX * (delta * delta - phi2 - v - expX);
      final double den = 2.0 * (phi2 + v + expX) * (phi2 + v + expX);
      return (num / den) - ((x - a) / (_tau * _tau));
    }

    double A = a;
    double B;

    if (delta * delta > (phi * phi + v)) {
      B = math.log(delta * delta - phi * phi - v);
    } else {
      double k = 1.0;
      while (f(a - k * _tau) < 0) {
        k += 1.0;
      }
      B = a - k * _tau;
    }

    double fA = f(A);
    double fB = f(B);

    while ((B - A).abs() > _epsilon) {
      final double C = A + (A - B) * fA / (fB - fA);
      final double fC = f(C);

      if (fC * fB < 0) {
        A = B;
        fA = fB;
      } else {
        fA = fA / 2.0;
      }
      B = C;
      fB = fC;
    }

    final double newSigma = math.exp(A / 2.0);

    // Step 6: Update Rating Deviation phi*
    final double phiStar = math.sqrt(phi * phi + newSigma * newSigma);

    // Step 7: Update Rating mu' and RD phi'
    final double newPhi = 1.0 / math.sqrt(1.0 / (phiStar * phiStar) + 1.0 / v);
    final double newMu = mu + newPhi * newPhi * deltaSum;

    // Step 8: Convert back to original Glicko scale
    return RatingState(
      rating: 1500.0 + _scale * newMu,
      rd: _scale * newPhi,
      volatility: newSigma,
    );
  }

  /// Convenience method for 1-on-1 match results.
  static Map<String, RatingState> applyMatchResult({
    required RatingState playerA,
    required RatingState playerB,
    required bool aWon,
  }) {
    final double scoreA = aWon ? 1.0 : 0.0;
    final double scoreB = aWon ? 0.0 : 1.0;

    final newA = updateRating(playerA, [MatchOutcome(opponent: playerB, score: scoreA)]);
    final newB = updateRating(playerB, [MatchOutcome(opponent: playerA, score: scoreB)]);

    return {'playerA': newA, 'playerB': newB};
  }
}
