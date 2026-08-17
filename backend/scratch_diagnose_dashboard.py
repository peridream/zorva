from app.db import supabase
import sys
import traceback

user_id = "cb53950b-4549-41b2-8f5b-8e79c3abe34c"

try:
    print("1. Profile...")
    p_res = supabase.table("profiles").select("*").eq("id", user_id).maybe_single().execute()
    print("Profile OK:", bool(p_res.data))

    print("2. Ratings...")
    r_res = (
        supabase.table("player_context_ratings")
        .select("*, rating_contexts(id, name, type)")
        .eq("user_id", user_id)
        .execute()
    )
    print("Ratings count:", len(r_res.data or []))

    print("3. Verified matches...")
    m_res = (
        supabase.table("matches")
        .select("*, creator:creator_id(id, full_name, username, avatar_url), opponent:opponent_id(id, full_name, username, avatar_url)")
        .or_(f"creator_id.eq.{user_id},opponent_id.eq.{user_id}")
        .eq("status", "verified")
        .order("logged_at", desc=True)
        .limit(10)
        .execute()
    )
    print("Verified matches count:", len(m_res.data or []))

    print("4. Pending matches...")
    pending_res = (
        supabase.table("matches")
        .select("*, creator:creator_id(id, full_name, username, avatar_url)")
        .eq("opponent_id", user_id)
        .eq("status", "pending")
        .order("logged_at", desc=True)
        .execute()
    )
    print("Pending matches count:", len(pending_res.data or []))

    print("5. Subscription...")
    s_res = supabase.table("premium_subscriptions").select("*").eq("user_id", user_id).maybe_single().execute()
    print("Sub:", s_res.data)

    print("\nSUCCESS: All dashboard database queries succeeded without errors!")
except Exception as e:
    traceback.print_exc()
