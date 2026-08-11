"""
Subscription endpoints — status checking, trial expiration, and subscription plan metadata.
"""

from fastapi import APIRouter, HTTPException
from app.db import supabase

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])

TRIAL_MAX_MATCHES = 10
FLAGSHIP_PLANS = {"founder_flagship", "flagship"}


@router.get("/{user_id}")
def get_user_subscription(user_id: str):
    """Fetch subscription plan and status for a given user."""
    res = (
        supabase.table("premium_subscriptions")
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

    # Get total verified matches count
    matches_res = (
        supabase.table("matches")
        .select("id", count="exact")
        .or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}")
        .eq("status", "verified")
        .execute()
    )
    verified_matches_count = matches_res.count or len(matches_res.data or [])

    is_flagship = status == "active" and plan_id in FLAGSHIP_PLANS
    is_trial_active = status == "active" and plan_id == "community_trial" and verified_matches_count <= TRIAL_MAX_MATCHES
    is_trial_expired = (plan_id == "community_trial" and verified_matches_count > TRIAL_MAX_MATCHES) or status == "expired"

    remaining_trial_matches = max(0, TRIAL_MAX_MATCHES - verified_matches_count)

    return {
        "user_id": user_id,
        "plan_id": plan_id,
        "status": "expired" if is_trial_expired and plan_id == "community_trial" else status,
        "is_flagship": is_flagship,
        "is_trial_active": is_trial_active,
        "is_trial_expired": is_trial_expired,
        "verified_matches_count": verified_matches_count,
        "remaining_trial_matches": remaining_trial_matches,
    }


def check_and_expire_trial_server(user_id: str) -> None:
    """Helper to check and expire community_trial if verified matches > 10."""
    res = (
        supabase.table("premium_subscriptions")
        .select("*")
        .eq("user_id", user_id)
        .execute()
    )
    if not res.data:
        return

    sub = res.data[0]
    if sub.get("plan_id") != "community_trial" or sub.get("status") != "active":
        return

    matches_res = (
        supabase.table("matches")
        .select("id", count="exact")
        .or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}")
        .eq("status", "verified")
        .execute()
    )
    verified_count = matches_res.count or len(matches_res.data or [])

    if verified_count > TRIAL_MAX_MATCHES:
        supabase.table("premium_subscriptions").update({
            "status": "expired"
        }).eq("user_id", user_id).execute()
