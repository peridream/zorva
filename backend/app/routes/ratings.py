"""
Rating endpoints — leaderboard retrieval, context listing, and user rating cards.
"""

from fastapi import APIRouter, HTTPException
from app.db import supabase

router = APIRouter(prefix="/ratings", tags=["ratings"])


@router.get("/contexts")
def list_contexts():
    """List available rating contexts (Community, Flagship, Clubs, etc.)."""
    res = supabase.table("rating_contexts").select("*").execute()
    return res.data or []


@router.get("/user/{user_id}")
@router.get("/{user_id}")
def get_user_ratings(user_id: str):
    """Fetch all formatted context ratings for a specific player."""
    res = (
        supabase.table("player_context_ratings")
        .select("*, rating_contexts(id, name, type)")
        .eq("user_id", user_id)
        .execute()
    )
    
    # Check monetization mode from app_settings
    is_growth_mode = True
    try:
        sett_res = supabase.table("app_settings").select("value").eq("key", "monetization_enabled").maybe_single().execute()
        if sett_res.data and str(sett_res.data.get("value")).lower() == "true":
            is_growth_mode = False
    except Exception:
        pass

    formatted_ratings = []
    for r in (res.data or []):
        ctx = r.get("rating_contexts") or {}
        if isinstance(ctx, list) and len(ctx) > 0:
            ctx = ctx[0]
        
        raw_type = ctx.get("type", "flagship") if isinstance(ctx, dict) else "flagship"
        raw_name = ctx.get("name", "Official Flagship Rating") if isinstance(ctx, dict) else "Official Flagship Rating"

        # During Growth Mode, all ratings are official Flagship ratings
        context_type = "flagship" if is_growth_mode else raw_type
        context_name = "OFFICIAL FLAGSHIP RATING" if is_growth_mode or context_type == "flagship" else raw_name.upper()

        wins = r.get("wins") or 0
        losses = r.get("losses") or 0
        matches_played = r.get("matches_played") or (wins + losses)
        win_rate = round((wins / matches_played) * 100) if matches_played > 0 else 0

        formatted_ratings.append({
            "id": r.get("id"),
            "user_id": r.get("user_id"),
            "context_id": r.get("context_id"),
            "rating": round(r.get("rating", 1500)),
            "rd": round(r.get("rd", 350), 1),
            "volatility": r.get("volatility", 0.06),
            "wins": wins,
            "losses": losses,
            "matches_played": matches_played,
            "win_rate": win_rate,
            "context_type": context_type,
            "context_name": context_name,
            "rating_contexts": ctx,
        })

    # Sort so Flagship rating is always index 0
    formatted_ratings.sort(key=lambda x: 0 if x.get("context_type") == "flagship" else 1)

    return formatted_ratings


@router.get("/leaderboard/{context_id}")
def get_leaderboard(context_id: str, limit: int = 50):
    """Fetch top ranked players for a given rating context."""
    res = (
        supabase.table("player_context_ratings")
        .select("*, profiles!user_id(id, username, full_name, city, is_founder, avatar_url)")
        .eq("context_id", context_id)
        .order("rating", desc=True)
        .limit(limit)
        .execute()
    )
    
    leaderboard = []
    for idx, row in enumerate(res.data or [], start=1):
        row["rank"] = idx
        leaderboard.append(row)
        
    return leaderboard
