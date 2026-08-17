from app.db import supabase
res = supabase.table("matches").select("*").limit(1).execute()
print("Matches columns:", res.data[0].keys() if res.data else "None")
