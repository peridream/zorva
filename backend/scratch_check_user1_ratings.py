from app.db import supabase

# Find User1 profile
p_res = supabase.table("profiles").select("*").ilike("full_name", "%User1%").execute()
print("Profiles found:", p_res.data)

for p in (p_res.data or []):
    u_id = p["id"]
    r_res = supabase.table("player_context_ratings").select("*, rating_contexts(*)").eq("user_id", u_id).execute()
    print(f"\nRatings for {p['full_name']} ({u_id}):")
    for r in (r_res.data or []):
        print(" -> Rating row:", r)
