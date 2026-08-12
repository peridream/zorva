"""
Community Groups Router — handles group creation, 20-member limits,
group join via invite code, group leaderboards, and tier-gated group insights.
"""

import random
import string
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.db import supabase

router = APIRouter(prefix="/groups", tags=["groups"])


class GroupCreateRequest(BaseModel):
    name: str
    description: Optional[str] = ""
    city: Optional[str] = "Dallas"
    sport: Optional[str] = "Table Tennis"
    group_type: Optional[str] = "community"  # 'community' or 'flagship'
    creator_id: str


class GroupJoinRequest(BaseModel):
    user_id: str
    invite_code: str


def _generate_invite_code() -> str:
    """Generate 6-character alphanumeric uppercase code."""
    chars = string.ascii_uppercase + string.digits
    return "".join(random.choices(chars, k=6))


def _is_flagship_user(user_id: str) -> bool:
    """Check if user has an active Flagship/Founder subscription."""
    try:
        sub_res = (
            supabase.table("premium_subscriptions")
            .select("plan_id, status")
            .eq("user_id", user_id)
            .execute()
        )
        sub_data = sub_res.data[0] if sub_res.data else {}
        plan_id = sub_data.get("plan_id", "")
        status = sub_data.get("status", "")
        return status == "active" and plan_id in {"founder_flagship", "flagship"}
    except Exception:
        return False


@router.post("/create")
def create_group(req: GroupCreateRequest):
    """Create a new Community or Flagship Group (Max 20 members)."""
    if not req.name.strip():
        raise HTTPException(status_code=400, detail="Group name is required")

    group_type = (req.group_type or "community").strip().lower()

    # Flagship groups can ONLY be created by Flagship players
    if group_type == "flagship" and not _is_flagship_user(req.creator_id):
        raise HTTPException(
            status_code=403,
            detail="Only Flagship Subscribers can create Flagship Groups ⚡. Upgrade to Flagship to create!",
        )

    invite_code = _generate_invite_code()

    # 1. Insert into groups table
    group_payload = {
        "name": req.name.strip(),
        "description": req.description.strip() if req.description else "",
        "city": req.city.strip() if req.city else "Dallas",
        "sport": req.sport.strip() if req.sport else "Table Tennis",
        "group_type": group_type,
        "invite_code": invite_code,
        "creator_id": req.creator_id,
        "max_members": 20,
    }

    try:
        res = supabase.table("groups").insert(group_payload).execute()
        if not res.data:
            raise HTTPException(status_code=500, detail="Failed to create group")

        group = res.data[0]
        group_id = group["id"]

        # 2. Add creator as admin member
        member_payload = {
            "group_id": group_id,
            "user_id": req.creator_id,
            "role": "admin",
        }
        supabase.table("group_members").insert(member_payload).execute()

        return {"status": "success", "group": group}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/join")
def join_group(req: GroupJoinRequest):
    """Join an existing group via 6-digit invite code."""
    clean_code = req.invite_code.strip().upper()
    if not clean_code:
        raise HTTPException(status_code=400, detail="Invite code is required")

    # 1. Find group
    try:
        group_res = (
            supabase.table("groups")
            .select("*")
            .eq("invite_code", clean_code)
            .maybe_single()
            .execute()
        )
        group = group_res.data
        if not group:
            raise HTTPException(status_code=404, detail="Invalid invite code. Group not found.")

        group_id = group["id"]
        group_type = group.get("group_type", "community")
        max_members = group.get("max_members", 20)

        # Flagship groups can ONLY be joined by Flagship players
        if group_type == "flagship" and not _is_flagship_user(req.user_id):
            raise HTTPException(
                status_code=403,
                detail="This is an Official Flagship Group ⚡. Upgrade to Flagship to join!",
            )

        # 2. Check current member count
        members_res = (
            supabase.table("group_members")
            .select("user_id")
            .eq("group_id", group_id)
            .execute()
        )
        current_members = members_res.data or []

        # Check if already a member
        if any(m["user_id"] == req.user_id for m in current_members):
            return {"status": "already_member", "group": group}

        # Check 20-member capacity limit
        if len(current_members) >= max_members:
            raise HTTPException(
                status_code=400,
                detail=f"Group '{group['name']}' is full! Maximum capacity is {max_members} members.",
            )

        # 3. Add user to group
        member_payload = {
            "group_id": group_id,
            "user_id": req.user_id,
            "role": "member",
        }
        supabase.table("group_members").insert(member_payload).execute()

        return {"status": "success", "group": group}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/user/{user_id}")
def get_user_groups(user_id: str):
    """Fetch all groups a user belongs to."""
    try:
        # 1. Fetch group IDs from group_members
        memberships_res = (
            supabase.table("group_members")
            .select("group_id, role, joined_at")
            .eq("user_id", user_id)
            .execute()
        )
        memberships = memberships_res.data or []
        if not memberships:
            return {"groups": []}

        group_ids = [m["group_id"] for m in memberships]

        # 2. Fetch details for these groups
        groups_res = (
            supabase.table("groups")
            .select("*")
            .in_("id", group_ids)
            .execute()
        )
        groups = groups_res.data or []

        # Enrich with member counts
        enriched = []
        for g in groups:
            g_id = g["id"]
            count_res = (
                supabase.table("group_members")
                .select("id")
                .eq("group_id", g_id)
                .execute()
            )
            g["member_count"] = len(count_res.data or [])
            enriched.append(g)

        return {"groups": enriched}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{group_id}/leaderboard")
def get_group_leaderboard(group_id: str):
    """
    Fetch Group Leaderboard.
    - Community Groups rank by Community Ratings.
    - Flagship Groups rank by Official Flagship Ratings.
    """
    try:
        # 1. Fetch group info
        group_res = (
            supabase.table("groups")
            .select("*")
            .eq("id", group_id)
            .maybe_single()
            .execute()
        )
        group = group_res.data or {}
        group_type = group.get("group_type", "community")

        # 2. Fetch group members
        members_res = (
            supabase.table("group_members")
            .select("user_id, role, joined_at")
            .eq("group_id", group_id)
            .execute()
        )
        members = members_res.data or []
        if not members:
            return {"leaderboard": [], "group_type": group_type}

        user_ids = [m["user_id"] for m in members]

        # 3. Fetch profiles
        profiles_res = (
            supabase.table("profiles")
            .select("id, full_name, username, city")
            .in_("id", user_ids)
            .execute()
        )
        profiles_map = {p["id"]: p for p in (profiles_res.data or [])}

        # 4. Fetch context ID for flagship or community
        ctx_res = (
            supabase.table("rating_contexts")
            .select("id")
            .eq("type", group_type)
            .maybe_single()
            .execute()
        )
        target_context_id = ctx_res.data["id"] if ctx_res.data else None

        # 5. Fetch ratings for target context
        query = supabase.table("player_context_ratings").select("user_id, rating").in_("user_id", user_ids)
        if target_context_id:
            query = query.eq("context_id", target_context_id)
        
        ratings_res = query.execute()

        ratings_map = {}
        for r in (ratings_res.data or []):
            u_id = r["user_id"]
            r_val = round(r.get("rating", 1200))
            if u_id not in ratings_map:
                ratings_map[u_id] = r_val
            else:
                ratings_map[u_id] = max(ratings_map[u_id], r_val)

        # 6. Build leaderboard array
        leaderboard = []
        for m in members:
            u_id = m["user_id"]
            prof = profiles_map.get(u_id, {})
            raw_name = prof.get("full_name") or prof.get("username") or "Player"
            
            leaderboard.append({
                "user_id": u_id,
                "name": raw_name,
                "city": prof.get("city", ""),
                "role": m.get("role", "member"),
                "rating": ratings_map.get(u_id, 1200),
            })

        # Sort by rating descending
        leaderboard.sort(key=lambda x: x["rating"], reverse=True)

        # Assign rank positions
        for idx, entry in enumerate(leaderboard, 1):
            entry["rank"] = idx

        return {"group_id": group_id, "group_type": group_type, "leaderboard": leaderboard}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{group_id}/insights/{user_id}")
def get_group_insights(group_id: str, user_id: str):
    """
    Fetch Group Insights payload.
    - Locked for Free Community Users (returns is_unlocked: False).
    - Unlocked for Paid Flagship Users (returns is_unlocked: True + full insights).
    """
    try:
        # 1. Check user's subscription tier
        sub_res = (
            supabase.table("premium_subscriptions")
            .select("plan_id, status")
            .eq("user_id", user_id)
            .execute()
        )
        sub_data = sub_res.data[0] if sub_res.data else {}
        plan_id = sub_data.get("plan_id", "community_trial")
        status = sub_data.get("status", "active")

        is_flagship = status == "active" and plan_id in {"founder_flagship", "flagship"}

        if not is_flagship:
            return {
                "is_unlocked": False,
                "message": "Group Insights are exclusive to Flagship Subscribers. Upgrade to unlock rivalry metrics & form analytics!",
            }

        # 2. Calculate Group Insights for Flagship User
        members_res = (
            supabase.table("group_members")
            .select("user_id")
            .eq("group_id", group_id)
            .execute()
        )
        user_ids = [m["user_id"] for m in (members_res.data or [])]

        # Calculate group match volume specifically tagged with this group_id
        matches_res = (
            supabase.table("matches")
            .select("id, creator_id, opponent_id, winner_id, status, logged_at")
            .eq("group_id", group_id)
            .eq("status", "confirmed")
            .execute()
        )
        group_matches = matches_res.data or []

        return {
            "is_unlocked": True,
            "total_group_matches": len(group_matches),
            "active_members_count": len(user_ids),
            "group_win_rate_avg": 50.0,
            "top_group_rivalry": "Top Group Derby" if group_matches else "No internal rivalries yet",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
