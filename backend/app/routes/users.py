"""
User endpoints — fetch users for profile display & opponent lookup.
"""

from fastapi import APIRouter, HTTPException
from app.db import supabase

router = APIRouter(prefix="/users", tags=["users"])


@router.get("")
def list_users():
    """List all registered users for opponent selection & directory."""
    res = supabase.table("users").select("id, username, display_name, avatar_url, city").execute()
    return res.data


@router.get("/{user_id}")
def get_user(user_id: str):
    """Fetch user profile details by ID."""
    res = supabase.table("users").select("*").eq("id", user_id).execute()
    if not res.data:
        raise HTTPException(404, "User not found")
    return res.data[0]
