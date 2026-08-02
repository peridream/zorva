-- Agon (working name — see /config/brand.ts for the single place this is set)
-- Database schema v2
-- Target: Postgres 15+ (Supabase)
--
-- Key design change from v1: rating is no longer two fixed columns
-- (community/official) on player_sport_profiles. It's now generalized
-- into "rating contexts" — community, flagship (the paid/opt-in tier,
-- branded "Agon Rating" in the UI but never named that in code), club,
-- corporate, age-group, etc. A player can hold a rating in any number
-- of contexts simultaneously, and a single confirmed match can update
-- several contexts at once.
--
-- Nothing in this file references the brand name. Renaming the app
-- later touches zero rows and zero columns here.

create extension if not exists "pgcrypto";

-- ============================================================
-- CORE IDENTITY
-- ============================================================

create table users (
  id              uuid primary key default gen_random_uuid(),
  username        text unique not null,
  display_name    text not null,
  avatar_url      text,
  email           text unique,
  phone           text unique,
  city            text,
  birth_year      int,                -- year only, not full DOB — enough for age-group eligibility
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint users_username_format check (username ~ '^[a-z0-9_]{3,20}$')
);

create index idx_users_city on users (city);

-- ============================================================
-- SPORTS (extensible — table tennis first, more added as rows)
-- ============================================================

create table sports (
  id              serial primary key,
  slug            text unique not null,
  name            text not null,
  scoring_type    text not null,
  is_active       boolean not null default true
);

insert into sports (slug, name, scoring_type) values
  ('table_tennis', 'Table Tennis', 'sets_to_11');

-- ============================================================
-- RATING CONTEXTS (generalized — replaces fixed community/official)
-- ============================================================

create table rating_contexts (
  id                  uuid primary key default gen_random_uuid(),
  sport_id            int not null references sports(id),

  type                text not null check (type in
                        ('community','flagship','club','corporate','age_group')),

  -- machine-readable scope, meaning depends on type:
  --   club       -> club_id (references clubs.id, added below)
  --   corporate  -> verified email domain, e.g. 'visa.com'
  --   age_group  -> bracket key, e.g. '40+'
  --   community/flagship -> null (one global context per sport)
  scope_key           text,

  name                text not null,      -- display name, e.g. "Austin TT Club League"
  is_public            boolean not null default true,
  requires_approval    boolean not null default false,
  auto_qualify_rule    text,               -- e.g. 'email_domain', 'birth_year', null = manual join

  created_at          timestamptz not null default now(),

  unique (sport_id, type, scope_key)
);

-- Every sport gets exactly one community context and one flagship
-- context automatically (seeded per sport, see below). Club/corporate/
-- age_group contexts are created as clubs/companies/brackets are added.

create index idx_rating_contexts_sport_type on rating_contexts (sport_id, type);

-- ============================================================
-- CLUBS (backing entity for 'club' rating contexts)
-- ============================================================

create table clubs (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  city          text,
  created_by    uuid references users(id),   -- admin-created for MVP, see roadmap note
  created_at    timestamptz not null default now()
);

-- ============================================================
-- CONTEXT MEMBERSHIP (who's eligible/opted-in to a given context)
-- ============================================================

create table context_memberships (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  context_id    uuid not null references rating_contexts(id) on delete cascade,
  status        text not null default 'active' check (status in ('active','pending','revoked')),
  joined_at     timestamptz not null default now(),

  unique (user_id, context_id)
);

create index idx_memberships_user on context_memberships (user_id, status);

-- ============================================================
-- PLAYER RATINGS PER CONTEXT (replaces player_sport_profiles rating cols)
-- ============================================================

create table player_context_ratings (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references users(id) on delete cascade,
  context_id        uuid not null references rating_contexts(id) on delete cascade,

  rating            numeric(7,2) not null default 1500,
  rd                numeric(7,2) not null default 350,     -- Glicko-2 rating deviation
  volatility        numeric(8,6) not null default 0.06,

  matches_played    int not null default 0,
  wins              int not null default 0,
  losses            int not null default 0,
  current_streak    int not null default 0,

  updated_at        timestamptz not null default now(),

  unique (user_id, context_id)
);

create index idx_pcr_context_rating on player_context_ratings (context_id, rating desc);

-- ============================================================
-- PLAYER SPORT SUMMARY (lightweight — powers "which sports do I play")
-- ============================================================

create table player_sport_summary (
  user_id           uuid not null references users(id) on delete cascade,
  sport_id          int not null references sports(id),
  first_played_at   timestamptz not null default now(),

  primary key (user_id, sport_id)
);

-- ============================================================
-- MATCHES
-- ============================================================

create table matches (
  id                uuid primary key default gen_random_uuid(),
  sport_id          int not null references sports(id),

  player1_id        uuid not null references users(id),
  player2_id        uuid not null references users(id),

  score_json        jsonb not null,
  winner_id         uuid not null references users(id),

  status            text not null default 'pending_confirmation'
                      check (status in ('pending_confirmation','confirmed','disputed','expired')),

  recorded_by       uuid not null references users(id),
  created_at        timestamptz not null default now(),
  confirmed_at      timestamptz,
  expires_at        timestamptz not null default (now() + interval '48 hours'),

  constraint different_players check (player1_id <> player2_id),
  constraint winner_is_participant check (winner_id in (player1_id, player2_id))
);

create index idx_matches_player1 on matches (player1_id, created_at desc);
create index idx_matches_player2 on matches (player2_id, created_at desc);
create index idx_matches_status on matches (status) where status = 'pending_confirmation';

-- ============================================================
-- MATCH <-> CONTEXT LINKS (which contexts this match updated, and how)
-- ============================================================

create table match_context_links (
  id                    uuid primary key default gen_random_uuid(),
  match_id              uuid not null references matches(id) on delete cascade,
  context_id            uuid not null references rating_contexts(id),

  p1_rating_before      numeric(7,2) not null,
  p1_rating_after       numeric(7,2) not null,
  p2_rating_before      numeric(7,2) not null,
  p2_rating_after       numeric(7,2) not null,

  created_at            timestamptz not null default now(),

  unique (match_id, context_id)
);

create index idx_match_context_links_match on match_context_links (match_id);
create index idx_match_context_links_context on match_context_links (context_id, created_at desc);

-- ============================================================
-- MATCH CONFIRMATIONS
-- ============================================================

create table match_confirmations (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid not null references matches(id) on delete cascade,
  user_id       uuid not null references users(id),
  action        text not null check (action in ('confirmed','disputed')),
  created_at    timestamptz not null default now(),

  unique (match_id, user_id)
);

-- ============================================================
-- FLAGSHIP UNLOCKS (v1.1 — city founders / paid unlock for the flagship context)
-- ============================================================

create table flagship_unlocks (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references users(id) on delete cascade,
  sport_id          int not null references sports(id),
  unlock_method     text not null check (unlock_method in ('city_founder_free','paid')),
  amount_paid_cents int,
  currency          text,
  unlocked_at       timestamptz not null default now(),

  unique (user_id, sport_id)
);

-- ============================================================
-- TITLES (earned only, scoped per context — v1.2)
-- ============================================================

create table titles (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  context_id    uuid not null references rating_contexts(id),
  title_key     text not null,     -- e.g. 'top_1_percent_2026'
  awarded_at    timestamptz not null default now()
);

create index idx_titles_user on titles (user_id);

-- ============================================================
-- PREMIUM SUBSCRIPTIONS (v1.2 — app-wide, not per context)
-- ============================================================

create table premium_subscriptions (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references users(id) on delete cascade,
  status                text not null check (status in ('trialing','active','canceled','expired')),
  trial_ends_at         timestamptz,
  current_period_end    timestamptz,
  created_at            timestamptz not null default now()
);

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_users_updated_at
  before update on users
  for each row execute function set_updated_at();

create trigger trg_pcr_updated_at
  before update on player_context_ratings
  for each row execute function set_updated_at();

-- ============================================================
-- SEED: every sport auto-gets a community + flagship context
-- ============================================================

insert into rating_contexts (sport_id, type, scope_key, name, is_public, requires_approval)
select id, 'community', null, name || ' — Community', true, false from sports
union all
select id, 'flagship', null, name || ' — Flagship', true, false from sports;
