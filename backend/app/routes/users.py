"""
User endpoints — registration, profile management, and opponent lookup.
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional, List
import datetime
from app.db import supabase

router = APIRouter(prefix="/users", tags=["users"])


class UserRegisterRequest(BaseModel):
    user_id: str
    email: Optional[str] = None
    username: str
    full_name: str
    city: str
    sport: str = "Table Tennis"
    self_rating: float = 1200.0
    experience_years: int = 1
    play_frequency: str = "1-2 times/week"
    play_style: str = "All-Round"


class UserProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    username: Optional[str] = None
    city: Optional[str] = None
    avatar_url: Optional[str] = None
    play_style: Optional[str] = None
    playing_hand: Optional[str] = None
    grip_style: Optional[str] = None
    rubber_type: Optional[str] = None
    skill_level: Optional[str] = None
    play_frequency: Optional[str] = None
    experience_years: Optional[int] = None
    self_rating: Optional[float] = None
    seen_milestones: Optional[List[str]] = None


@router.post("/register")
def register_user(req: UserRegisterRequest):
    """
    Atomic registration:
    1. Determines city founder status based on existing player count.
    2. Upserts profile in `profiles`.
    3. Creates subscription record in `subscriptions`.
    4. Initializes single Official Flagship rating in `player_context_ratings`.
    """
    user_id = req.user_id
    city = req.city.strip()

    # 1. Fetch founder cap from app_settings
    founder_cap = 20
    try:
        cap_res = supabase.table("app_settings").select("value").eq("key", "founder_cap_per_city").maybe_single().execute()
        if cap_res.data and cap_res.data.get("value"):
            founder_cap = int(cap_res.data["value"])
    except Exception:
        pass

    # 2. Count existing players in city
    try:
        count_res = supabase.table("profiles").select("id", count="exact").eq("city", city).execute()
        city_count = count_res.count or len(count_res.data or [])
    except Exception:
        city_count = 0

    rank = city_count + 1
    is_founder = rank <= founder_cap

    # 3. Upsert Profile
    profile_data = {
        "id": user_id,
        "email": req.email.strip() if req.email else None,
        "username": req.username.strip(),
        "full_name": req.full_name.strip(),
        "city": city,
        "is_founder": is_founder,
        "updated_at": datetime.datetime.utcnow().isoformat(),
    }
    supabase.table("profiles").upsert(profile_data).execute()

    # 4. Upsert Subscription (Founding players get 100% Lifetime Free Flagship, others get dynamic trial)
    if is_founder:
        plan_id = "founder_flagship"
        trial_ends_at = None
    else:
        plan_id = "community_trial"
        trial_duration_days = 365
        try:
            trial_res = supabase.table("app_settings").select("value").eq("key", "trial_duration_days").maybe_single().execute()
            if trial_res.data and trial_res.data.get("value"):
                trial_duration_days = int(trial_res.data["value"])
        except Exception:
            pass
        trial_ends_at = (datetime.datetime.utcnow() + datetime.timedelta(days=trial_duration_days)).isoformat()

    sub_data = {
        "user_id": user_id,
        "plan_id": plan_id,
        "status": "active",
        "trial_ends_at": trial_ends_at,
        "updated_at": datetime.datetime.utcnow().isoformat(),
    }
    supabase.table("subscriptions").upsert(sub_data).execute()

    # 5. Initialize Single Official Flagship Rating
    ctx_res = supabase.table("rating_contexts").select("id").eq("type", "flagship").maybe_single().execute()
    if ctx_res.data:
        ctx_id = ctx_res.data["id"]
        pcr_data = {
            "user_id": user_id,
            "context_id": ctx_id,
            "rating": req.self_rating,
            "rd": 250.0,
            "volatility": 0.06,
            "wins": 0,
            "losses": 0,
            "matches_played": 0,
        }
        supabase.table("player_context_ratings").upsert(pcr_data).execute()

    return {
        "success": True,
        "user_id": user_id,
        "rank": rank,
        "is_founder": is_founder,
        "plan_id": plan_id,
        "trial_ends_at": trial_ends_at,
        "profile": profile_data,
    }


@router.get("/opponents")
def get_opponents(
    city: Optional[str] = None,
    search: Optional[str] = None,
    exclude_user_id: Optional[str] = None,
    limit: int = 20,
):
    """Fetch potential match opponents with optional search & city filter."""
    query = supabase.table("profiles").select("id, username, full_name, city, is_founder, avatar_url")
    
    if city and city.strip():
        query = query.eq("city", city.strip())
    if exclude_user_id:
        query = query.neq("id", exclude_user_id)
    if search and search.strip():
        query = query.ilike("full_name", f"%{search.strip()}%")
        
    res = query.limit(limit).execute()
    return res.data or []


@router.get("/profile/{user_id}")
def get_user_profile(user_id: str):
    """Fetch user profile details and city rank."""
    res = supabase.table("profiles").select("*").eq("id", user_id).maybe_single().execute()
    if not res.data:
        raise HTTPException(404, "User not found")
    return res.data


@router.put("/profile/{user_id}")
def update_user_profile(user_id: str, req: UserProfileUpdateRequest):
    """Update user profile attributes and starting rating if provided."""
    update_data = {k: v for k, v in req.dict().items() if v is not None}
    if not update_data:
        return {"message": "Nothing to update"}
        
    self_rating = update_data.pop("self_rating", None)
    if self_rating is not None:
        try:
            flagship_ctx = supabase.table("rating_contexts").select("id").eq("type", "flagship").maybe_single().execute()
            if flagship_ctx.data:
                supabase.table("player_context_ratings").update({
                    "rating": self_rating,
                    "updated_at": datetime.datetime.utcnow().isoformat(),
                }).eq("user_id", user_id).eq("context_id", flagship_ctx.data["id"]).execute()
        except Exception:
            pass

    if update_data:
        update_data["updated_at"] = datetime.datetime.utcnow().isoformat()
        res = supabase.table("profiles").update(update_data).eq("id", user_id).execute()
        return {"success": True, "profile": res.data[0] if res.data else None}
    return {"success": True}


@router.get("/check-duplicate")
def check_duplicate(full_name: str, city: str):
    """Check if a profile with the same full name and city already exists."""
    res = (
        supabase.table("profiles")
        .select("id, full_name, city, email, phone")
        .ilike("full_name", full_name.strip())
        .ilike("city", city.strip())
        .execute()
    )
    return res.data or []


@router.get("/lookup")
def lookup_user(query: str):
    """Lookup user by email, phone, or username."""
    clean_q = query.strip()
    res = (
        supabase.table("profiles")
        .select("*")
        .or_(f"email.eq.{clean_q},phone.eq.{clean_q},username.eq.{clean_q}")
        .execute()
    )
    return res.data or []


@router.get("/dashboard/{user_id}")
def get_user_dashboard(user_id: str):
    """
    Consolidated dashboard payload:
    - User profile
    - Ratings (with context details)
    - Verified recent matches
    - Pending incoming match approvals
    - Subscription status
    """
    # 1. Profile
    p_res = supabase.table("profiles").select("*").eq("id", user_id).maybe_single().execute()
    profile = p_res.data or {}

    # 2. Ratings
    r_res = (
        supabase.table("player_context_ratings")
        .select("*, rating_contexts(id, name, type)")
        .eq("user_id", user_id)
        .execute()
    )
    ratings = r_res.data or []

    # 3. Confirmed matches (recent 10)
    m_res = (
        supabase.table("matches")
        .select("*, creator:creator_id(id, full_name, username, avatar_url), opponent:opponent_id(id, full_name, username, avatar_url)")
        .or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}")
        .eq("status", "confirmed")
        .order("logged_at", desc=True)
        .limit(10)
        .execute()
    )
    verified_matches = m_res.data or []

    # 4. Pending incoming matches requiring user confirmation
    pending_res = (
        supabase.table("matches")
        .select("*, creator:creator_id(id, full_name, username, avatar_url)")
        .eq("opponent_id", user_id)
        .eq("status", "pending")
        .order("logged_at", desc=True)
        .execute()
    )
    pending_matches = pending_res.data or []

    # 5. Subscription
    s_res = supabase.table("subscriptions").select("*").eq("user_id", user_id).maybe_single().execute()
    subscription = s_res.data or {}

    return {
        "profile": profile,
        "ratings": ratings,
        "verified_matches": verified_matches,
        "pending_matches": pending_matches,
        "subscription": subscription,
    }
