from app.db import supabase

# Update all existing founding members to have grandfathered_until = None (Lifetime Free)
res = (
    supabase.table("premium_subscriptions")
    .update({"grandfathered_until": None, "status": "active"})
    .eq("is_founder", True)
    .execute()
)
print("Updated founding players in DB to Lifetime Free:", len(res.data or []))
