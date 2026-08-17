import datetime
from fastapi import APIRouter, HTTPException
from app.db import supabase

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])

FLAGSHIP_PLANS = {"founder_flagship", "flagship"}


@router.get("/{user_id}")
def get_user_subscription(user_id: str):
    """Fetch subscription plan and status for a given user."""
    res = (
        supabase.table("subscriptions")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )
    
    if res.data:
        sub = res.data[0]
    else:
        # Default fallback for users without subscription record
        sub = {
            "user_id": user_id,
            "plan_id": "community_trial",
            "status": "active",
        }

    plan_id = sub.get("plan_id", "community_trial")
    status = sub.get("status", "active")
    is_founder = sub.get("is_founder", False) or plan_id == "founder_flagship"
    trial_ends_at_str = sub.get("trial_ends_at")

    # Check app_settings for monetization mode
    is_growth_phase = True
    try:
        sett_res = supabase.table("app_settings").select("value").eq("key", "monetization_enabled").maybe_single().execute()
        if sett_res.data and str(sett_res.data.get("value")).lower() == "true":
            is_growth_phase = False
    except Exception:
        pass

    # Parse trial_ends_at
    trial_ends_at = None
    days_remaining = None
    if trial_ends_at_str:
        try:
            trial_ends_at = datetime.datetime.fromisoformat(trial_ends_at_str.replace("Z", "+00:00"))
        except Exception:
            pass

    now_utc = datetime.datetime.now(datetime.timezone.utc)

    # Get total verified matches count
    matches_res = (
        supabase.table("matches")
        .select("id", count="exact")
        .or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}")
        .eq("status", "confirmed")
        .execute()
    )
    verified_matches_count = matches_res.count or len(matches_res.data or [])

    # Evaluate Flagship access
    if is_founder or plan_id == "founder_flagship":
        is_flagship = True
        is_trial_active = False
        is_trial_expired = False
        effective_plan = "founder_flagship"
    elif plan_id == "flagship" and status == "active":
        is_flagship = True
        is_trial_active = False
        is_trial_expired = False
        effective_plan = "flagship"
    elif plan_id == "community_trial":
        if trial_ends_at is not None:
            days_remaining = max(0, (trial_ends_at - now_utc).days)
            if now_utc < trial_ends_at:
                is_flagship = True
                is_trial_active = True
                is_trial_expired = False
                effective_plan = "community_trial"
            else:
                is_flagship = False or is_growth_phase
                is_trial_active = False
                is_trial_expired = True
                effective_plan = "community" if not is_growth_phase else "community_trial"
        else:
            is_flagship = True
            is_trial_active = True
            is_trial_expired = False
            effective_plan = "community_trial"
    else:
        # plan_id == "community" or unknown
        is_flagship = False or is_growth_phase
        is_trial_active = False
        is_trial_expired = True
        effective_plan = "community" if not is_growth_phase else "community_trial"

    return {
        "user_id": user_id,
        "plan_id": effective_plan,
        "raw_plan_id": plan_id,
        "status": "expired" if is_trial_expired and not is_founder and plan_id != "flagship" else status,
        "is_flagship": is_flagship,
        "is_founder": is_founder,
        "is_growth_phase": is_growth_phase,
        "is_trial_active": is_trial_active,
        "is_trial_expired": is_trial_expired,
        "trial_ends_at": trial_ends_at_str,
        "days_remaining": days_remaining,
        "verified_matches_count": verified_matches_count,
    }
