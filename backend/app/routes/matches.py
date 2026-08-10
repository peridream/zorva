"""
Match endpoints — record a match, confirm/dispute it, and (on
confirmation) apply Glicko-2 rating updates across every eligible
rating context in a single transaction-like sequence.

This is the core loop: Add Match -> opponent Confirms -> ratings update.
"""

from fastapi import APIRouter, HTTPException
from datetime import datetime, timezone

from app.db import supabase
from app.models.match import RecordMatchRequest, ConfirmMatchRequest
from app.rating_engine.glicko2 import RatingState, apply_match_result, DEFAULT_RATING

router = APIRouter(prefix="/matches", tags=["matches"])


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

def _get_or_create_context_rating(user_id: str, context_id: str) -> dict:
    """Fetch a player's rating row for a context, creating a default
    one (1500/350/0.06) if this is their first match in it."""
    existing = (
        supabase.table("player_context_ratings")
        .select("*")
        .eq("user_id", user_id)
        .eq("context_id", context_id)
        .execute()
    )
    if existing.data:
        return existing.data[0]

    created = (
        supabase.table("player_context_ratings")
        .insert({
            "user_id": user_id,
            "context_id": context_id,
            "rating": DEFAULT_RATING.rating,
            "rd": DEFAULT_RATING.rd,
            "volatility": DEFAULT_RATING.volatility,
        })
        .execute()
    )
    return created.data[0]


def _get_eligible_contexts(sport_id: int, player1_id: str, player2_id: str) -> list[dict]:
    """
    A match is eligible to update a rating context if:
      - it's the 'community' context for this sport (everyone is always eligible), OR
      - both players have an 'active' context_membership row for that context
        (covers flagship, club, corporate, age_group alike — the schema
        treats them uniformly)
    """
    contexts = (
        supabase.table("rating_contexts")
        .select("*")
        .eq("sport_id", sport_id)
        .execute()
        .data
    )

    eligible = []
    for ctx in contexts:
        if ctx["type"] == "community":
            eligible.append(ctx)
            continue

        memberships = (
            supabase.table("context_memberships")
            .select("user_id")
            .eq("context_id", ctx["id"])
            .eq("status", "active")
            .in_("user_id", [player1_id, player2_id])
            .execute()
            .data
        )
        member_ids = {m["user_id"] for m in memberships}
        if {player1_id, player2_id}.issubset(member_ids):
            eligible.append(ctx)

    return eligible


def _apply_ratings_for_confirmed_match(match: dict) -> None:
    """Runs once, when a match transitions to 'confirmed'. Updates
    every eligible rating context and records the before/after values."""
    p1, p2 = match["player1_id"], match["player2_id"]
    p1_won = match["winner_id"] == p1

    eligible_contexts = _get_eligible_contexts(match["sport_id"], p1, p2)

    for ctx in eligible_contexts:
        p1_row = _get_or_create_context_rating(p1, ctx["id"])
        p2_row = _get_or_create_context_rating(p2, ctx["id"])

        p1_state = RatingState(rating=p1_row["rating"], rd=p1_row["rd"], volatility=p1_row["volatility"])
        p2_state = RatingState(rating=p2_row["rating"], rd=p2_row["rd"], volatility=p2_row["volatility"])

        new_p1, new_p2 = apply_match_result(p1_state, p2_state, a_won=p1_won)

        supabase.table("player_context_ratings").update({
            "rating": new_p1.rating, "rd": new_p1.rd, "volatility": new_p1.volatility,
            "matches_played": p1_row["matches_played"] + 1,
            "wins": p1_row["wins"] + (1 if p1_won else 0),
            "losses": p1_row["losses"] + (0 if p1_won else 1),
            "current_streak": (p1_row["current_streak"] + 1) if p1_won else (
                -1 if p1_row["current_streak"] >= 0 else p1_row["current_streak"] - 1
            ),
        }).eq("id", p1_row["id"]).execute()

        supabase.table("player_context_ratings").update({
            "rating": new_p2.rating, "rd": new_p2.rd, "volatility": new_p2.volatility,
            "matches_played": p2_row["matches_played"] + 1,
            "wins": p2_row["wins"] + (0 if p1_won else 1),
            "losses": p2_row["losses"] + (1 if p1_won else 0),
            "current_streak": (p2_row["current_streak"] + 1) if not p1_won else (
                -1 if p2_row["current_streak"] >= 0 else p2_row["current_streak"] - 1
            ),
        }).eq("id", p2_row["id"]).execute()

        supabase.table("match_context_links").insert({
            "match_id": match["id"],
            "context_id": ctx["id"],
            "p1_rating_before": p1_state.rating, "p1_rating_after": new_p1.rating,
            "p2_rating_before": p2_state.rating, "p2_rating_after": new_p2.rating,
        }).execute()


# ------------------------------------------------------------------
# Endpoints
# ------------------------------------------------------------------

@router.post("")
def record_match(body: RecordMatchRequest):
    """Submit a new match result. Stays 'pending_confirmation' until
    the opponent confirms (the recorder's submission counts as their
    own implicit confirmation)."""
    if body.winner_id not in (body.player1_id, body.player2_id):
        raise HTTPException(400, "winner_id must be one of the two players")
    if body.player1_id == body.player2_id:
        raise HTTPException(400, "A player cannot play against themself")

    match = supabase.table("matches").insert({
        "sport_id": body.sport_id,
        "player1_id": str(body.player1_id),
        "player2_id": str(body.player2_id),
        "winner_id": str(body.winner_id),
        "score_json": body.score_json,
        "recorded_by": str(body.recorded_by),
    }).execute().data[0]

    # the recorder's submission counts as their confirmation
    supabase.table("match_confirmations").insert({
        "match_id": match["id"],
        "user_id": str(body.recorded_by),
        "action": "confirmed",
    }).execute()

    return match


@router.post("/{match_id}/confirm")
def confirm_match(match_id: str, body: ConfirmMatchRequest):
    match = supabase.table("matches").select("*").eq("id", match_id).execute().data
    if not match:
        raise HTTPException(404, "Match not found")
    match = match[0]

    if match["status"] != "pending_confirmation":
        raise HTTPException(400, f"Match is already {match['status']}")

    if str(body.user_id) not in (match["player1_id"], match["player2_id"]):
        raise HTTPException(403, "Only match participants can confirm or dispute")

    supabase.table("match_confirmations").insert({
        "match_id": match_id,
        "user_id": str(body.user_id),
        "action": body.action,
    }).execute()

    if body.action == "disputed":
        supabase.table("matches").update({"status": "disputed"}).eq("id", match_id).execute()
        return {"status": "disputed"}

    confirmations = (
        supabase.table("match_confirmations")
        .select("user_id, action")
        .eq("match_id", match_id)
        .execute()
        .data
    )
    confirmed_user_ids = {c["user_id"] for c in confirmations if c["action"] == "confirmed"}
    both_confirmed = {match["player1_id"], match["player2_id"]}.issubset(confirmed_user_ids)

    if both_confirmed:
        supabase.table("matches").update({
            "status": "confirmed",
            "confirmed_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", match_id).execute()

        match["status"] = "confirmed"
        _apply_ratings_for_confirmed_match(match)
        return {"status": "confirmed", "ratings_updated": True}

    return {"status": "pending_confirmation", "waiting_on_other_player": True}


@router.get("/{match_id}")
def get_match(match_id: str):
    match = supabase.table("matches").select("*").eq("id", match_id).execute().data
    if not match:
        raise HTTPException(404, "Match not found")
    return match[0]


@router.get("/pending/{user_id}")
def get_pending_confirmations(user_id: str):
    """Matches this user still needs to act on — feeds the
    Confirmation screen / push notification badge."""
    matches = (
        supabase.table("matches")
        .select("*")
        .eq("status", "pending_confirmation")
        .or_(f"player1_id.eq.{user_id},player2_id.eq.{user_id}")
        .execute()
        .data
    )
    result = []
    for m in matches:
        my_confirmation = (
            supabase.table("match_confirmations")
            .select("id")
            .eq("match_id", m["id"])
            .eq("user_id", user_id)
            .execute()
            .data
        )
        if not my_confirmation:
            result.append(m)
    return result


@router.get("/user/{user_id}")
def get_user_matches(user_id: str, limit: int = 20):
    """Fetch recent matches involving a specific user, joining player names."""
    matches = (
        supabase.table("matches")
        .select("*, p1:player1_id(display_name, username), p2:player2_id(display_name, username)")
        .or_(f"player1_id.eq.{user_id},player2_id.eq.{user_id}")
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
        .data
    )
    return matches