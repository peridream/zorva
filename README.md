# Zorva (working name — folder and name can still change, see brand.ts) — project structure

This is the starting scaffold discussed in the planning chat.
Nothing here is wired up yet — it's the folder layout + the two
design artifacts we've built so far (schema, brand config).

```
.
├── apps/
│   └── mobile/               React Native/Expo app (not yet initialized)
│       └── config/
│           └── brand.ts      Single source of truth for the app name
├── backend/
│   └── app/
│       ├── models/           FastAPI/SQLAlchemy models (not yet written)
│       ├── routes/           API endpoints (not yet written)
│       └── rating_engine/    Glicko-2 rating logic (next thing to build)
├── supabase/
│   └── migrations/
│       └── 0001_init_schema.sql   Run this in Supabase SQL editor, or via `supabase db push`
└── docs/                      Roadmap notes, decisions, etc.
```

## Setup steps (once you're ready to start running code)

1. `git init` in this folder, then push it to a repo (GitHub/GitLab).
2. Create a Supabase project → SQL editor → paste and run
   `supabase/migrations/0001_init_schema.sql`.
3. `npx create-expo-app apps/mobile` (or point the Expo CLI at the
   existing `apps/mobile` folder) to scaffold the RN app around the
   existing `config/brand.ts`.
4. `python -m venv backend/.venv && pip install fastapi uvicorn` to
   start the backend.

## Renaming the app later

Edit `apps/mobile/config/brand.ts` only. Nothing in the database
schema or backend code references the brand name — see the comment
at the top of that file for why.
