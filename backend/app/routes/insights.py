"""
Insights & Analytics endpoint — fetches player trajectory, win streaks,
form guide, and rivalries in a single server-side API call.
"""

from fastapi import APIRouter, HTTPException
from app.db import supabase

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("/{user_id}")
def get_player_insights(user_id: str):
    """Fetch complete insights dashboard payload for a given player."""

    # 1. Determine User Subscription Tier (Flagship vs Community)
    sub_res = (
        supabase.table("premium_subscriptions")
        .select("plan_id, status")
        .eq("user_id", user_id)
        .execute()
    )
    sub_data = sub_res.data[0] if sub_res.data else {}
    plan_id = sub_data.get("plan_id", "community_trial")
    sub_status = sub_data.get("status", "active")

    is_flagship = sub_status == "active" and plan_id in {"founder_flagship", "flagship"}
    target_context_type = "flagship" if is_flagship else "community"

    # 2. Fetch rating contexts and player ratings for target context
    ratings_res = (
        supabase.table("player_context_ratings")
        .select("rating, context_id, rating_contexts(id, name, type)")
        .eq("user_id", user_id)
        .execute()
    )

    current_rating = 1500
    peak_rating = 1500
    active_context_id = None
    ratings_list = ratings_res.data or []

    if ratings_list:
        chosen_card = None
        for r in ratings_list:
            ctx = r.get("rating_contexts")
            if isinstance(ctx, dict) and ctx.get("type") == target_context_type:
                chosen_card = r
                break
            elif isinstance(ctx, list) and ctx and ctx[0].get("type") == target_context_type:
                chosen_card = r
                break
        
        if not chosen_card:
            chosen_card = ratings_list[0]

        current_rating = round(chosen_card.get("rating", 1500))
        all_r_vals = [round(r.get("rating", 1500)) for r in ratings_list]
        peak_rating = max(all_r_vals) if all_r_vals else 1500
        active_context_id = chosen_card.get("context_id")

    # 3. Fetch context-specific matches via match_context_links
    context_matches = []
    history_points = []

    if active_context_id:
        try:
            links_res = (
                supabase.table("match_context_links")
                .select("*")
                .eq("context_id", active_context_id)
                .order("created_at", desc=False)
                .execute()
            )
            links = links_res.data or []

            if links:
                match_ids = [l["match_id"] for l in links if l.get("match_id")]
                match_map = {}
                if match_ids:
                    m_details = (
                        supabase.table("matches")
                        .select("*")
                        .in_("id", match_ids)
                        .execute()
                        .data or []
                    )
                    match_map = {m["id"]: m for m in m_details}

                user_links = []
                for l in links:
                    m = match_map.get(l.get("match_id"), {})
                    p1 = m.get("creator_id") or m.get("player1_id")
                    p2 = m.get("opponent_id") or m.get("player2_id")
                    if p1 == user_id or p2 == user_id or not m:
                        user_links.append((l, m))
                        if m:
                            context_matches.append(m)

                if user_links:
                    first_l, first_m = user_links[0]
                    p1_0 = first_m.get("creator_id") or first_m.get("player1_id")
                    initial_rating = first_l.get("p1_rating_before") if (p1_0 == user_id or not p1_0) else first_l.get("p2_rating_before")
                    if initial_rating is not None:
                        history_points.append(float(initial_rating))

                    for l, m in user_links:
                        p1 = m.get("creator_id") or m.get("player1_id")
                        rating_after = l.get("p1_rating_after") if (p1 == user_id or not p1) else l.get("p2_rating_after")
                        if rating_after is not None:
                            history_points.append(float(rating_after))
        except Exception as e:
            print(f"Context matches fetch note: {e}")

    # Fallback to direct matches query if context links are empty
    if not context_matches:
        try:
            m_res = (
                supabase.table("matches")
                .select("*")
                .or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}")
                .eq("status", "verified")
                .order("logged_at", desc=False)
                .execute()
            )
            context_matches = m_res.data or []
        except Exception:
            pass

    # 4. Calculate Form Guide & Streaks strictly for this context
    form = []
    current_streak = 0
    streak_active = True
    max_streak = 0
    temp_streak = 0

    opp_wins = {}
    opp_losses = {}

    for m in context_matches:
        p1 = m.get("creator_id") or m.get("player1_id")
        p2 = m.get("opponent_id") or m.get("player2_id")
        winner = m.get("winner_id")
        is_win = winner == user_id
        opp_id = p2 if p1 == user_id else p1

        if len(form) < 5:
            form.append("W" if is_win else "L")

        if is_win:
            if streak_active:
                current_streak += 1
            temp_streak += 1
            if temp_streak > max_streak:
                max_streak = temp_streak
            opp_wins[opp_id] = opp_wins.get(opp_id, 0) + 1
        else:
            streak_active = False
            temp_streak = 0
            opp_losses[opp_id] = opp_losses.get(opp_id, 0) + 1

    form_guide = list(reversed(form[:5]))

    # 3. Trajectory History Points
    history_points = []
    if active_context_id:
        try:
            links_res = (
                supabase.table("match_context_links")
                .select("*")
                .eq("context_id", active_context_id)
                .order("created_at", desc=False)
                .execute()
            )
            links = links_res.data or []

            if links:
                # Fetch associated match details
                match_ids = [l["match_id"] for l in links if l.get("match_id")]
                match_map = {}
                if match_ids:
                    m_details = (
                        supabase.table("matches")
                        .select("*")
                        .in_("id", match_ids)
                        .execute()
                        .data or []
                    )
                    match_map = {m["id"]: m for m in m_details}

                user_links = []
                for l in links:
                    m = match_map.get(l.get("match_id"), {})
                    p1 = m.get("creator_id") or m.get("player1_id")
                    p2 = m.get("opponent_id") or m.get("player2_id")
                    if p1 == user_id or p2 == user_id or not m:
                        user_links.append((l, m))

                if user_links:
                    first_l, first_m = user_links[0]
                    p1_0 = first_m.get("creator_id") or first_m.get("player1_id")
                    initial_rating = first_l.get("p1_rating_before") if (p1_0 == user_id or not p1_0) else first_l.get("p2_rating_before")
                    if initial_rating is not None:
                        history_points.append(float(initial_rating))

                    for l, m in user_links:
                        p1 = m.get("creator_id") or m.get("player1_id")
                        rating_after = l.get("p1_rating_after") if (p1 == user_id or not p1) else l.get("p2_rating_after")
                        if rating_after is not None:
                            history_points.append(float(rating_after))
        except Exception as e:
            print(f"Trajectory query note: {e}")

    if not history_points:
        history_points = [float(current_rating)]

    # Peak rating strictly derived from target context rating history
    peak_rating = round(max(history_points))

    return {
        "user_id": user_id,
        "current_rating": current_rating,
        "peak_rating": peak_rating,
        "win_streak": current_streak,
        "best_win_streak": max_streak,
        "form_guide": form_guide,
        "trajectory_points": history_points,
    }
