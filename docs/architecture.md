# Zorva Technical Architecture & Schema Reference

This document details the system architecture, database schema, and rating context design for **Zorva**.

---

## 1. System Architecture Diagram

```
+-------------------------------------------------------------+
|                  Zorva Flutter Mobile App                   |
|         (Clean Architecture: Presentation / Domain)         |
+------------------------------+------------------------------+
                               |
                               | Direct HTTPS / WebSockets
                               v
+-------------------------------------------------------------+
|                  Supabase Cloud Platform                    |
|  +-------------------+  +--------------------------------+  |
|  |   PostgreSQL 15+  |  |  Realtime WebSockets (Alerts)  |  |
|  +-------------------+  +--------------------------------+  |
|  | Row Level Sec.    |  |  Supabase Auth                 |  |
|  +-------------------+  +--------------------------------+  |
+-------------------------------------------------------------+
```

---

## 2. PostgreSQL Database Schema

### Migrations
* `0001_init_schema.sql` — Core identity, sports, rating contexts, player context ratings, matches, confirmations, links.
* `0002_init_schema.sql` — Dynamic sport views trigger (`trg_create_sport_views`).
* `0003_enable_public_rls.sql` — RLS policies for client application access.

### Core Tables

#### `users`
* `id` (UUID, PK)
* `username` (Text, Unique)
* `display_name` (Text)
* `city` (Text)
* `birth_year` (Int)

#### `sports`
* `id` (Serial, PK)
* `slug` (Text, Unique) — e.g. `table_tennis`
* `name` (Text)
* `scoring_type` (Text) — e.g. `sets_to_11`

#### `rating_contexts`
* `id` (UUID, PK)
* `sport_id` (FK -> `sports.id`)
* `type` (Text) — `community`, `flagship`, `club`, `corporate`, `age_group`
* `name` (Text)

#### `player_context_ratings`
* `id` (UUID, PK)
* `user_id` (FK -> `users.id`)
* `context_id` (FK -> `rating_contexts.id`)
* `rating` (Numeric 7,2) — Glicko-2 rating
* `rd` (Numeric 7,2) — Glicko-2 rating deviation
* `volatility` (Numeric 8,6) — Glicko-2 volatility
* `matches_played` (Int)
* `wins` (Int)
* `losses` (Int)
* `current_streak` (Int)

#### `matches`
* `id` (UUID, PK)
* `sport_id` (FK -> `sports.id`)
* `player1_id` (FK -> `users.id`)
* `player2_id` (FK -> `users.id`)
* `winner_id` (FK -> `users.id`)
* `score_json` (JSONB)
* `status` (Text) — `pending_confirmation`, `confirmed`, `disputed`, `expired`
* `recorded_by` (FK -> `users.id`)
