from app.db import supabase
res = supabase.table("rating_contexts").select("*").limit(1).execute()
print("Rating contexts columns:", res.data[0].keys() if res.data else "None")
