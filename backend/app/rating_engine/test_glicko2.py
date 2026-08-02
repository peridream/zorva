"""
Tests for the Glicko-2 rating engine.

Run with: pytest test_glicko2.py -v
"""

import math
import pytest
from glicko2 import (
    RatingState,
    MatchOutcome,
    update_rating,
    apply_match_result,
    decay_inactive_rd,
    DEFAULT_RATING,
)


def test_glickman_worked_example():
    """
    Reproduces the exact worked example from Glickman's Glicko-2 paper
    (section on 'Example of the Glicko-2 system'). A player rated
    1500/200/0.06 plays three opponents in one period and should end
    up at approximately 1464.06 / 151.52 / 0.05999.

    This is the single most important test in this file — if this
    passes, the core math is correct.
    """
    player = RatingState(rating=1500, rd=200, volatility=0.06)

    opponents = [
        MatchOutcome(opponent=RatingState(1400, 30, 0.06), score=1.0),
        MatchOutcome(opponent=RatingState(1550, 100, 0.06), score=0.0),
        MatchOutcome(opponent=RatingState(1700, 300, 0.06), score=0.0),
    ]

    result = update_rating(player, opponents)

    assert result.rating == pytest.approx(1464.06, abs=0.5)
    assert result.rd == pytest.approx(151.52, abs=0.5)
    assert result.volatility == pytest.approx(0.05999, abs=0.0001)


def test_new_player_defaults():
    assert DEFAULT_RATING.rating == 1500.0
    assert DEFAULT_RATING.rd == 350.0
    assert DEFAULT_RATING.volatility == 0.06


def test_winner_rating_increases_loser_decreases():
    a = RatingState(rating=1500, rd=100, volatility=0.06)
    b = RatingState(rating=1500, rd=100, volatility=0.06)

    new_a, new_b = apply_match_result(a, b, a_won=True)

    assert new_a.rating > a.rating
    assert new_b.rating < b.rating


def test_beating_higher_rated_player_gains_more():
    """Winning against a stronger opponent should yield more rating
    gain than winning against a weaker one — this is the core
    property that makes the system meaningful."""
    challenger = RatingState(rating=1200, rd=80, volatility=0.06)
    weak_opponent = RatingState(rating=1100, rd=80, volatility=0.06)
    strong_opponent = RatingState(rating=1600, rd=80, volatility=0.06)

    gain_vs_weak, _ = apply_match_result(challenger, weak_opponent, a_won=True)
    gain_vs_strong, _ = apply_match_result(challenger, strong_opponent, a_won=True)

    assert (gain_vs_strong.rating - challenger.rating) > (
        gain_vs_weak.rating - challenger.rating
    )


def test_new_player_rd_drops_faster_than_established_player():
    """A brand-new player (high RD) should see a bigger rating swing
    from one match than an established player (low RD) — this is the
    whole point of using Glicko-2 over plain Elo for casual/amateur play."""
    new_player = RatingState(rating=1500, rd=350, volatility=0.06)
    established_player = RatingState(rating=1500, rd=50, volatility=0.06)
    opponent = RatingState(rating=1500, rd=100, volatility=0.06)

    new_result, _ = apply_match_result(new_player, opponent, a_won=True)
    established_result, _ = apply_match_result(established_player, opponent, a_won=True)

    new_player_swing = abs(new_result.rating - new_player.rating)
    established_player_swing = abs(established_result.rating - established_player.rating)

    assert new_player_swing > established_player_swing
    # and RD should shrink after playing
    assert new_result.rd < new_player.rd


def test_draw_moves_both_ratings_toward_each_other_less_drastically():
    a = RatingState(rating=1600, rd=100, volatility=0.06)
    b = RatingState(rating=1400, rd=100, volatility=0.06)

    new_a = update_rating(a, [MatchOutcome(opponent=b, score=0.5)])
    new_b = update_rating(b, [MatchOutcome(opponent=a, score=0.5)])

    # higher-rated player drawing a lower-rated player should lose rating
    assert new_a.rating < a.rating
    # lower-rated player drawing a higher-rated player should gain rating
    assert new_b.rating > b.rating


def test_update_rating_requires_at_least_one_outcome():
    player = RatingState(rating=1500, rd=100, volatility=0.06)
    with pytest.raises(ValueError):
        update_rating(player, [])


def test_decay_inactive_rd_increases_uncertainty():
    player = RatingState(rating=1500, rd=50, volatility=0.06)
    decayed = decay_inactive_rd(player, rating_periods_inactive=10)

    assert decayed.rd > player.rd
    assert decayed.rating == player.rating  # rating itself doesn't move, only RD


def test_decay_inactive_rd_is_capped_at_starting_value():
    player = RatingState(rating=1500, rd=340, volatility=0.06)
    decayed = decay_inactive_rd(player, rating_periods_inactive=1000)

    assert decayed.rd <= 350.0


def test_rating_state_is_immutable():
    player = RatingState(rating=1500, rd=100, volatility=0.06)
    with pytest.raises(Exception):
        player.rating = 1600  # frozen dataclass — should raise


if __name__ == "__main__":
    import sys
    sys.exit(pytest.main([__file__, "-v"]))
