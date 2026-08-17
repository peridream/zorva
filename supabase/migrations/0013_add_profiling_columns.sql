-- Migration: 0013_add_profiling_columns.sql
-- Description: Add progressive profiling attributes (equipment, playstyle) to profiles

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS playing_hand TEXT,
  ADD COLUMN IF NOT EXISTS play_style TEXT,
  ADD COLUMN IF NOT EXISTS grip_style TEXT,
  ADD COLUMN IF NOT EXISTS rubber_type TEXT,
  ADD COLUMN IF NOT EXISTS skill_level TEXT;
