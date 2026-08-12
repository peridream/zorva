# 🎾 Zorva Application Project Context & Handover Summary

> **Date**: August 12, 2026  
> **Purpose**: Complete context summary for initiating a fresh conversation session with zero context loss.

---

## 🚀 1. Tech Stack & Execution Commands

- **Mobile App**: Flutter (`apps/mobile_flutter`). Primary deployment target is **Mobile App (iOS/Android)**. Web release build is compiled for instant local preview (`flutter build web --release`).
- **Backend API**: Python FastAPI (`backend/app`). Served locally via `uvicorn app.main:app --port 8000 --reload`.
- **Database**: PostgreSQL (Supabase DB).
- **Active Local Servers**:
  - **FastAPI Backend**: `http://localhost:8000`
  - **Flutter Web Server**: `http://localhost:8080`

---

## ⚡ 2. Core Domain & Architectural Rules of Thumb

### Ratings & Baselines
1. **Onboarding Baseline Ratings**: New users are assigned an initial Glicko-2 rating based on self-reported skill category during onboarding:
   - **Beginner**: 1000.0
   - **Intermediate**: 1200.0
   - **Advanced**: 1500.0
   - **Semi-Pro / Pro**: 1800.0
   - Ratings settle naturally over played and verified matches.
2. **Founding Member Cap**: The first 100 registered players per city automatically receive `founder_flagship` status.
3. **Universal Rating Updating Rule**:
   - **Community Rating Context**: EVERY match submission (whether regular 1v1, group game, league match, etc.) updates the players' **Community Rating**.
   - **Flagship Rating Context**: Matches update the **Flagship Rating** *only if both participating players are active Flagship subscribers*.

### Groups & Navigation Architecture
1. **Dedicated Groups Hub**:
   - All group management takes place in the **3rd bottom navigation bar tab** (`GroupsListScreen`).
   - Group cards and buttons have been **completely removed from the Passport page** to keep Passport focused exclusively on player rating cards, match logs, and history.
2. **Streamlined Group Detail (`GroupDetailScreen`)**:
   - Clean top bar with Group Title + compact **Invite Code** chip (`ZORVA8 📋`).
   - Main screen contains **2 core tabs**: **LEADERBOARD 🏆** and **INSIGHTS 📈**.
3. **Flagship Groups ⚡ vs Community Groups 🎾**:
   - **Community Groups**: Open to all players. Leaderboards rank members by **Community Ratings**.
   - **Flagship Groups**: Can **ONLY** be created by Flagship Subscribers and **ONLY** Flagship Subscribers can join them via invite code (HTTP 403 / upgrade prompt for non-flagship users). Leaderboards rank members by **Official Flagship Ratings**.
   - **Group Creation Form**:
     - For non-flagship users, the `group_type` toggle switch is **completely hidden** and defaults automatically to **Community Group**.
     - For Flagship subscribers, the toggle switch (`COMMUNITY 🎾` vs `FLAGSHIP ⚡`) is displayed.
     - The **City** input field automatically pre-fills with the creator's registered profile city.

### Automatic Shared Group Match Tagging & Analytics
1. **Passport Match Logging**:
   - Matches are always logged from the **Passport** page.
   - When a match is submitted between Player A and Player B, the backend checks if both players share a common group.
   - If a shared group exists, `group_id` is automatically attached to the match record in the `matches` table.
2. **Isolated Group Analytics**:
   - Group Insights (`GET /groups/{group_id}/insights`) query matches strictly by `group_id = <group_id>`.
   - Historical matches played *before* group creation or outside the group context do NOT pollute group activity or rivalry analytics.

---

## 🗄️ 3. Database Schema & Migrations Summary

- **`profiles`**: User identities, onboarding city, Glicko-2 ratings (`rating`, `rd`, `volatility`).
- **`premium_subscriptions`**: Tracks `plan_id` (`founder_flagship`, `flagship`, `community_trial`) and `status` (`active`, `expired`).
- **`groups`**: Contains group metadata, `invite_code`, `max_members` (20 cap), `group_type` (`community` or `flagship`), and `created_at`.
- **`group_members`**: Group membership links (`group_id`, `user_id`, `role`, `joined_at`).
- **`matches`**:
  - `id`, `creator_id`, `opponent_id`, `sport`, `creator_score`, `opponent_score`, `winner_id`, `status` (`pending`, `verified`, `disputed`), `logged_at`.
  - `group_id`: Foreign key referencing `groups(id)` for automatic group match tagging.

### Migration Files Log:
- `0001_init_schema.sql`: Initial core schema.
- `0005_add_plan_id_to_premium_subscriptions.sql`: Added `plan_id` column to `premium_subscriptions`.
- `0006_create_community_groups.sql`: Created `groups` and `group_members` tables.
- `0007_add_group_type.sql`: Added `group_type TEXT DEFAULT 'community'` to `groups`.
- `0008_add_group_id_to_matches.sql`: Added `group_id UUID REFERENCES groups(id) ON DELETE SET NULL` to `matches`.

---

## 📁 4. Key File References

### Backend (`FastAPI`)
- [backend/app/routes/groups.py](file:///c:/zorva/backend/app/routes/groups.py): Group creation, joining, context-specific leaderboards, and group insights.
- [backend/app/routes/matches.py](file:///c:/zorva/backend/app/routes/matches.py): Match recording, implicit confirmation, Glicko-2 updates, and automatic shared group detection.
- [backend/app/routes/subscriptions.py](file:///c:/zorva/backend/app/routes/subscriptions.py): Subscription plan metadata and trial expiration logic.
- [backend/app/routes/ratings.py](file:///c:/zorva/backend/app/routes/ratings.py): Player ratings context router (`/ratings/contexts`, `/ratings/{user_id}`).

### Mobile Flutter App (`apps/mobile_flutter`)
- [groups_list_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/groups/presentation/screens/groups_list_screen.dart): Full-screen Groups Hub tab with Create Group and Join Code modals.
- [group_detail_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/groups/presentation/screens/group_detail_screen.dart): 2-tab view (Leaderboard & Insights) for group management.
- [home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart): Bottom navigation bar controller containing Home, Leaderboards, and Groups tabs.
- [api_service.dart](file:///c:/zorva/apps/mobile_flutter/lib/core/services/api_service.dart): Backend REST API client.

---

## 🎯 5. Quick Verification Check

To verify system health in a new session:
```powershell
# 1. Backend Server Check
Invoke-RestMethod -Uri "http://127.0.0.1:8000/docs"

# 2. Web Preview Check
Invoke-RestMethod -Uri "http://127.0.0.1:8080/"
```
