# Zorva — Pre-Backend Migration Snapshot

> **Created**: 2026-08-10  
> **Purpose**: Reference snapshot of the current Flutter client-side architecture **before** wiring up the FastAPI backend. Use this to understand what the Flutter app was doing directly, and as a rollback reference.

---

## Current Architecture (Client-Direct)

```
Flutter App
    │
    │  Direct HTTPS (PostgREST)
    ▼
Supabase PostgreSQL
    ├── matches
    ├── match_context_links
    ├── player_context_ratings
    ├── premium_subscriptions
    └── rating_contexts
```

The Flutter app currently talks **directly** to Supabase for everything — including running Glicko-2 rating calculations client-side.

---

## Target Architecture (After Backend Migration)

```
Flutter App
    │
    │  HTTP REST calls
    ▼
FastAPI Backend (c:\zorva\backend\)
    │
    │  Service Key (bypasses RLS)
    ▼
Supabase PostgreSQL
```

The FastAPI backend will own all business logic (Glicko-2, match ratification, subscription gating). Flutter becomes a pure UI layer.

---

## Key Flutter Files (Pre-Migration State)

### 1. Home Dashboard Screen
- **File**: [home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart)
- **What it does client-side today**:
  - Loads subscription plan/status directly from `premium_subscriptions`
  - Queries `matches` directly with `.or('creator_id.eq.$userId,opponent_id.eq.$userId')`
  - Counts total verified matches (uncapped query) for trial expiration
  - Calls `_checkAndUpdateTrialExpiration()` — writes `status = 'expired'` to Supabase directly from client
  - Runs `_quickApproveMatch()` — confirms matches and triggers Glicko-2 from Flutter
  - Renders rating history sparkline from `match_context_links` queried directly

### 2. Insights Screen
- **File**: [insights_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/insights_screen.dart)
- **What it does client-side today**:
  - Queries `player_context_ratings` with `rating_contexts(id, name, type)` embedded join
  - Prioritizes `flagship` context card if user has flagship membership
  - Queries `match_context_links` filtered by `context_id` for trajectory graph points
  - Computes win streaks, best streak, form guide, favorite/toughest opponent **all in Dart**
  - All analytics computed in-memory from raw match rows

### 3. Subscription Constants (Single Source of Truth)
- **File**: [subscription_constants.dart](file:///c:/zorva/apps/mobile_flutter/lib/core/constants/subscription_constants.dart)
- **Contents**: Plan IDs, status values, trial caps, and helper methods

### 4. Dart Glicko-2 Engine
- **File**: [glicko2.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/rating/domain/glicko2.dart)
- **Status**: Currently used client-side when matches are confirmed
- **Post-migration**: This file can be removed once backend handles all rating computation

---

## Backend (Already Built — Not Yet Connected)

### FastAPI Entry Point
- **File**: [main.py](file:///c:/zorva/backend/app/main.py)
- **Runs locally with**: `uvicorn app.main:app --reload`
- **Docs**: http://127.0.0.1:8000/docs

### Supabase DB Client
- **File**: [db.py](file:///c:/zorva/backend/app/db.py)
- Uses `SUPABASE_SERVICE_KEY` (bypasses RLS — full DB access)
- Credentials loaded from `backend/.env`

### Python Glicko-2 Engine
- **File**: [glicko2.py](file:///c:/zorva/backend/app/rating_engine/glicko2.py)
- **Key functions**:
  - `apply_match_result(player_a, player_b, a_won)` → `(RatingState, RatingState)`
  - `update_rating(player, outcomes)` → `RatingState`
  - `decay_inactive_rd(player, periods_inactive)` → `RatingState` *(not in Dart version!)*
  - `DEFAULT_RATING = RatingState(rating=1500.0, rd=350.0, volatility=0.06)`

### Match Routes (Core Business Logic)
- **File**: [matches.py](file:///c:/zorva/backend/app/routes/matches.py)
- **Endpoints**:
  - `POST /matches` — Record a new match (stays `pending_confirmation`)
  - `POST /matches/{id}/confirm` — Confirm or dispute; when both confirm → runs Glicko-2 → updates `player_context_ratings` → writes `match_context_links`
  - `GET /matches/{id}` — Fetch match by ID
  - `GET /matches/pending/{user_id}` — Matches needing confirmation action
  - `GET /matches/user/{user_id}` — Recent matches for a user

### Other Routes
- **File**: [ratings.py](file:///c:/zorva/backend/app/routes/ratings.py)
- **File**: [users.py](file:///c:/zorva/backend/app/routes/users.py)

---

## Database Schema Quick Reference

### `premium_subscriptions`
| Column | Type | Values |
|---|---|---|
| `user_id` | UUID | FK → profiles |
| `plan_id` | TEXT | `founder_flagship`, `flagship`, `community_trial` |
| `status` | TEXT | `active`, `expired` |

### `player_context_ratings`
| Column | Type | Notes |
|---|---|---|
| `user_id` | UUID | |
| `context_id` | UUID | FK → rating_contexts |
| `rating` | NUMERIC | Glicko-2 rating (default 1500) |
| `rd` | NUMERIC | Rating deviation (default 350) |
| `volatility` | NUMERIC | Glicko-2 volatility (default 0.06) |

### `match_context_links`
| Column | Type | Notes |
|---|---|---|
| `match_id` | UUID | |
| `context_id` | UUID | |
| `p1_rating_before` | NUMERIC | Used for trajectory graph |
| `p1_rating_after` | NUMERIC | Used for trajectory graph |
| `p2_rating_before` | NUMERIC | |
| `p2_rating_after` | NUMERIC | |

### `rating_contexts`
| Column | Type | Values |
|---|---|---|
| `type` | TEXT | `community`, `flagship`, `club`, `corporate`, `age_group` |

---

## Migration Checklist (Planned)

- [ ] **Step 1**: Deploy FastAPI backend (Railway / Render / Fly.io)
- [ ] **Step 2**: Add `BACKEND_URL` constant to Flutter app
- [ ] **Step 3**: Replace `_quickApproveMatch()` client call → `POST /matches/{id}/confirm`
- [ ] **Step 4**: Replace `_checkAndUpdateTrialExpiration()` client call → server-side endpoint
- [ ] **Step 5**: Replace `_loadInsightsData()` multi-query → single `GET /insights/{user_id}` call
- [ ] **Step 6**: Remove `glicko2.dart` from Flutter (no longer needed client-side)
- [ ] **Step 7**: Add auth token forwarding (Supabase JWT → FastAPI middleware)
