"""
Glicko-2 rating engine.

Pure functions only — no database access, no brand references, no
framework dependency. This module takes rating state in, returns new
rating state out. The API layer is responsible for reading/writing
`player_context_ratings` and `match_context_links`.

Reference: Mark Glickman's Glicko-2 paper
(http://www.glicko.net/glicko/glicko2.pdf). Each confirmed match is
treated as its own one-game rating period, which is the standard
adaptation for real-time apps (classic Glicko-2 assumes a batch of
games per period; treating N=1 is mathematically valid, just widens
swings slightly for very active players — acceptable for MVP).
"""

from dataclasses import dataclass
import math

# ---- Glicko-2 constants -----------------------------------------------

TAU = 0.5           # system volatility constraint — controls how much
                     # volatility can change over time. 0.3-1.2 is the
                     # typical range; 0.5 is a reasonable amateur-sport default
EPSILON = 0.000001   # convergence tolerance for volatility iteration
GLICKO2_SCALE = 173.7178


@dataclass(frozen=True)
class RatingState:
    """A player's rating state in the public Glicko scale (what you'd
    store in player_context_ratings and show in the UI)."""
    rating: float        # e.g. 1500
    rd: float            # rating deviation, e.g. 350
    volatility: float    # e.g. 0.06


@dataclass(frozen=True)
class MatchOutcome:
    """Result of a single match from one player's perspective."""
    opponent: RatingState
    score: float   # 1.0 = win, 0.5 = draw, 0.0 = loss


def _to_glicko2_scale(state: RatingState) -> tuple[float, float]:
    mu = (state.rating - 1500) / GLICKO2_SCALE
    phi = state.rd / GLICKO2_SCALE
    return mu, phi


def _from_glicko2_scale(mu: float, phi: float) -> tuple[float, float]:
    rating = mu * GLICKO2_SCALE + 1500
    rd = phi * GLICKO2_SCALE
    return rating, rd


def _g(phi: float) -> float:
    return 1 / math.sqrt(1 + 3 * phi**2 / math.pi**2)


def _E(mu: float, mu_j: float, phi_j: float) -> float:
    return 1 / (1 + math.exp(-_g(phi_j) * (mu - mu_j)))


def _new_volatility(phi: float, sigma: float, v: float, delta: float) -> float:
    """Illinois algorithm to solve for updated volatility (sigma')."""
    a = math.log(sigma**2)

    def f(x: float) -> float:
        ex = math.exp(x)
        num = ex * (delta**2 - phi**2 - v - ex)
        den = 2 * (phi**2 + v + ex) ** 2
        return (num / den) - ((x - a) / TAU**2)

    A = a
    if delta**2 > phi**2 + v:
        B = math.log(delta**2 - phi**2 - v)
    else:
        k = 1
        while f(a - k * TAU) < 0:
            k += 1
        B = a - k * TAU

    fA, fB = f(A), f(B)
    while abs(B - A) > EPSILON:
        C = A + (A - B) * fA / (fB - fA)
        fC = f(C)
        if fC * fB < 0:
            A, fA = B, fB
        else:
            fA = fA / 2
        B, fB = C, fC

    return math.exp(A / 2)


def update_rating(player: RatingState, outcomes: list[MatchOutcome]) -> RatingState:
    """
    Compute a player's new rating after one rating period.

    `outcomes` is the list of matches the player completed in this
    period. For real-time single-match confirmation, call this with
    a list of exactly one MatchOutcome.

    A player with zero outcomes (didn't play) should NOT call this —
    Glicko-2 handles inactivity by inflating RD over time via a
    separate decay step (see `decay_inactive_rd`), not via this function.
    """
    if not outcomes:
        raise ValueError("update_rating requires at least one match outcome")

    mu, phi = _to_glicko2_scale(player)
    sigma = player.volatility

    v_inv = 0.0
    delta_sum = 0.0
    for outcome in outcomes:
        mu_j, phi_j = _to_glicko2_scale(outcome.opponent)
        g_j = _g(phi_j)
        E_j = _E(mu, mu_j, phi_j)
        v_inv += g_j**2 * E_j * (1 - E_j)
        delta_sum += g_j * (outcome.score - E_j)

    v = 1 / v_inv
    delta = v * delta_sum

    sigma_prime = _new_volatility(phi, sigma, v, delta)

    phi_star = math.sqrt(phi**2 + sigma_prime**2)
    phi_prime = 1 / math.sqrt(1 / phi_star**2 + 1 / v)
    mu_prime = mu + phi_prime**2 * delta_sum

    new_rating, new_rd = _from_glicko2_scale(mu_prime, phi_prime)

    return RatingState(
        rating=round(new_rating, 2),
        rd=round(new_rd, 2),
        volatility=round(sigma_prime, 6),
    )


def decay_inactive_rd(player: RatingState, rating_periods_inactive: int) -> RatingState:
    """
    Widen RD for a player who didn't play during N rating periods,
    reflecting growing uncertainty about their current skill.

    Call this on a schedule (e.g. a weekly job) for players with no
    confirmed matches since their last update — not on every request.
    """
    mu, phi = _to_glicko2_scale(player)
    sigma = player.volatility

    phi_star = math.sqrt(phi**2 + rating_periods_inactive * sigma**2)
    _, new_rd = _from_glicko2_scale(mu, phi_star)

    # RD is capped at the starting value (350) — it shouldn't exceed
    # the uncertainty of a brand-new player
    new_rd = min(new_rd, 350.0)

    return RatingState(rating=player.rating, rd=round(new_rd, 2), volatility=sigma)


def apply_match_result(
    player_a: RatingState,
    player_b: RatingState,
    a_won: bool,
) -> tuple[RatingState, RatingState]:
    """
    Convenience wrapper for the common case: one confirmed 1v1 match,
    update both players' ratings against each other.

    This is what the API layer calls once per eligible rating context
    when a match is confirmed (see match_context_links in the schema —
    call this once per context the match counts toward).
    """
    a_score = 1.0 if a_won else 0.0
    b_score = 1.0 - a_score

    new_a = update_rating(player_a, [MatchOutcome(opponent=player_b, score=a_score)])
    new_b = update_rating(player_b, [MatchOutcome(opponent=player_a, score=b_score)])

    return new_a, new_b


DEFAULT_RATING = RatingState(rating=1500.0, rd=350.0, volatility=0.06)
