-- Migration 0004: Player Profiling Columns for Sports Passport
-- Target: Supabase Postgres

alter table users add column if not exists playing_hand text;
alter table users add column if not exists playstyle text;
alter table users add column if not exists grip_style text;
alter table users add column if not exists rubber_type text;
alter table users add column if not exists self_assessed_level text;
