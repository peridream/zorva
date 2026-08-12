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
    return res.data


@router.get("/user/{user_id}")
@router.get("/{user_id}")
def get_user_ratings(user_id: str):
    """Fetch all context ratings for a specific player."""
    res = (
        supabase.table("player_context_ratings")
        .select("*, rating_contexts(name, type, sport_id)")
        .eq("user_id", user_id)
        .execute()
    )
    return res.data


@router.get("/leaderboard/{context_id}")
def get_leaderboard(context_id: str, limit: int = 50):
    """Fetch top ranked players for a given rating context."""
    res = (
        supabase.table("player_context_ratings")
        .select("*, users(id, username, display_name, avatar_url, city)")
        .eq("context_id", context_id)
        .order("rating", desc=True)
        .limit(limit)
        .execute()
    )
    
    # Attach 1-based rank position
    leaderboard = []
    for idx, row in enumerate(res.data, start=1):
        row["rank"] = idx
        leaderboard.append(row)
        
    return leaderboard
