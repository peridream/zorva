# Supabase Database Schema & Code Mapping Guide

This document serves as the single source of truth for the Supabase database schema in **Zorva**, including detailed column definitions, SQL migration commands, and exact code mapping to application screens.

---

## ⚡ SQL Migration for League Admin Support

Run this command in **Supabase SQL Editor** to add the `role` column to `context_memberships`:

```sql
-- Add role column to context_memberships with 'player' default
ALTER TABLE context_memberships 
ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'player';
```

---

## 🗺️ Codebase to Supabase Table Mapping Matrix

| Table Name | Business Purpose | Key Files & Screens in Codebase | Primary Operations |
| :--- | :--- | :--- | :--- |
| **`profiles`** | Stores core player info (name, username, city, glicko rating, avatar). | [city_onboarding_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/onboarding/presentation/screens/city_onboarding_screen.dart)<br>[home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart)<br>[user_session.dart](file:///c:/zorva/apps/mobile_flutter/lib/core/config/user_session.dart) | Onboarding insert, user profile fetching, city player row counts. |
| **`matches`** | Historical & pending game logs between creators and opponents. | [add_match_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/match_logger/presentation/screens/add_match_screen.dart)<br>[home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart) | Sub-10s match logging, recent match history, 1-tap approval list. |
| **`city_rankings`** | Official city leaderboards and player ordinal rankings. | [leaderboards_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/leaderboards/presentation/screens/leaderboards_screen.dart)<br>[user_session.dart](file:///c:/zorva/apps/mobile_flutter/lib/core/config/user_session.dart) | City founder rank calculation, leaderboard ordering. |
| **`rating_contexts`** | Competition environments (Official Flagship, Community, Leagues, Tournaments). | [home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart)<br>[add_match_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/match_logger/presentation/screens/add_match_screen.dart) | Dual rating toggle, league environment selection. |
| **`context_memberships`** | Player league enrollments and roles (`admin`, `player`). | [home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart)<br>*(League Admin Screens - Upcoming)* | Joining leagues, verifying league admin rights. |
| **`player_context_ratings`** | Detailed Glicko-2 ratings, win/loss stats per league/context. | [home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart) | Passport hero card rating score, win/loss ratios. |
| **`match_confirmations`** | Two-player verification audit log for match approvals. | [add_match_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/match_logger/presentation/screens/add_match_screen.dart)<br>[home_dashboard_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/dashboard/presentation/screens/home_dashboard_screen.dart) | Instant match confirmation on submission. |
| **`clubs`** | Physical sports clubs, venues, and local communities. | [clubs_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/clubs/presentation/screens/clubs_screen.dart) | Club discovery and venue listings. |
| **`sports`** | Supported sports directory (Table Tennis, Pickleball, Padel). | [sports_selection_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/onboarding/presentation/screens/sports_selection_screen.dart) | Sport rules and active status lookup. |
| **`flagship_unlocks`** | Tracks lifetime official rating pass purchases. | [paywall_screen.dart](file:///c:/zorva/apps/mobile_flutter/lib/features/paywall/presentation/screens/paywall_screen.dart) | Checking official rating pass entitlement. |
| **`premium_subscriptions`** | Subscriptions and free trial periods. | [user_session.dart](file:///c:/zorva/apps/mobile_flutter/lib/core/config/user_session.dart) | Gating premium feature access. |
| **`match_context_links`** | Links individual matches to specific league ratings. | Glicko Rating Engine | Calculating rating deltas for league matches. |
| **`player_sport_summary`** | First played timestamps per sport. | Profile Summary | Historical career milestones. |
| **`table_tennis_ratings`** | Sport-specific rating view fallback. | Dashboard Fallbacks | Table tennis rating reference. |

---

## 📋 Full Column Schemas by Table

| table_name | column_name | data_type | is_nullable |
| :--- | :--- | :--- | :--- |
| **city_rankings** | id | uuid | NO |
| city_rankings | city | text | NO |
| city_rankings | sport | text | NO |
| city_rankings | player_id | uuid | NO |
| city_rankings | city_rank | integer | NO |
| city_rankings | glicko_rating | double precision | NO |
| city_rankings | updated_at | timestamp with time zone | YES |
| **clubs** | id | uuid | NO |
| clubs | name | text | NO |
| clubs | city | text | YES |
| clubs | created_by | uuid | YES |
| clubs | created_at | timestamp with time zone | NO |
| **context_memberships** | id | uuid | NO |
| context_memberships | user_id | uuid | NO |
| context_memberships | context_id | uuid | NO |
| context_memberships | **role** | text | NO |
| context_memberships | status | text | NO |
| context_memberships | joined_at | timestamp with time zone | NO |
| **flagship_unlocks** | id | uuid | NO |
| flagship_unlocks | user_id | uuid | NO |
| flagship_unlocks | sport_id | integer | NO |
| flagship_unlocks | unlock_method | text | NO |
| flagship_unlocks | amount_paid_cents | integer | YES |
| flagship_unlocks | currency | text | YES |
| flagship_unlocks | unlocked_at | timestamp with time zone | NO |
| **match_confirmations** | id | uuid | NO |
| match_confirmations | match_id | uuid | NO |
| match_confirmations | user_id | uuid | NO |
| match_confirmations | action | text | NO |
| match_confirmations | created_at | timestamp with time zone | NO |
| **match_context_links** | id | uuid | NO |
| match_context_links | match_id | uuid | NO |
| match_context_links | context_id | uuid | NO |
| match_context_links | p1_rating_before | numeric | NO |
| match_context_links | p1_rating_after | numeric | NO |
| match_context_links | p2_rating_before | numeric | NO |
| match_context_links | p2_rating_after | numeric | NO |
| match_context_links | created_at | timestamp with time zone | NO |
| **matches** | id | uuid | NO |
| matches | creator_id | uuid | NO |
| matches | opponent_id | uuid | YES |
| matches | sport | text | NO |
| matches | creator_score | integer | NO |
| matches | opponent_score | integer | NO |
| matches | winner_id | uuid | YES |
| matches | status | text | YES |
| matches | rating_change_creator | double precision | YES |
| matches | rating_change_opponent | double precision | YES |
| matches | logged_at | timestamp with time zone | YES |
| **player_context_ratings** | id | uuid | NO |
| player_context_ratings | user_id | uuid | NO |
| player_context_ratings | context_id | uuid | NO |
| player_context_ratings | rating | numeric | NO |
| player_context_ratings | rd | numeric | NO |
| player_context_ratings | volatility | numeric | NO |
| player_context_ratings | matches_played | integer | NO |
| player_context_ratings | wins | integer | NO |
| player_context_ratings | losses | integer | NO |
| player_context_ratings | current_streak | integer | NO |
| player_context_ratings | updated_at | timestamp with time zone | NO |
| **player_sport_summary** | user_id | uuid | NO |
| player_sport_summary | sport_id | integer | NO |
| player_sport_summary | first_played_at | timestamp with time zone | NO |
| **premium_subscriptions** | id | uuid | NO |
| premium_subscriptions | user_id | uuid | NO |
| premium_subscriptions | status | text | NO |
| premium_subscriptions | trial_ends_at | timestamp with time zone | YES |
| premium_subscriptions | current_period_end | timestamp with time zone | YES |
| premium_subscriptions | created_at | timestamp with time zone | NO |
| **profiles** | id | uuid | NO |
| profiles | email | text | YES |
| profiles | phone | text | YES |
| profiles | full_name | text | YES |
| profiles | username | text | YES |
| profiles | avatar_url | text | YES |
| profiles | primary_sport | text | YES |
| profiles | city | text | YES |
| profiles | glicko_rating | double precision | YES |
| profiles | rating_deviation | double precision | YES |
| profiles | volatility | double precision | YES |
| profiles | matches_played | integer | YES |
| profiles | created_at | timestamp with time zone | YES |
| profiles | updated_at | timestamp with time zone | YES |
| **rating_contexts** | id | uuid | NO |
| rating_contexts | sport_id | integer | NO |
| rating_contexts | type | text | NO |
| rating_contexts | scope_key | text | YES |
| rating_contexts | name | text | NO |
| rating_contexts | is_public | boolean | NO |
| rating_contexts | requires_approval | boolean | NO |
| rating_contexts | auto_qualify_rule | text | YES |
| rating_contexts | created_at | timestamp with time zone | NO |
| **sports** | id | integer | NO |
| sports | slug | text | NO |
| sports | name | text | NO |
| sports | scoring_type | text | NO |
| sports | is_active | boolean | NO |
| **table_tennis_ratings** | id | uuid | YES |
| table_tennis_ratings | user_id | uuid | YES |
| table_tennis_ratings | context_id | uuid | YES |
| table_tennis_ratings | rating | numeric | YES |
