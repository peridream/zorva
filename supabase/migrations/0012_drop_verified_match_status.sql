-- Migration: 0012_drop_verified_match_status.sql
-- Description: Standardize match statuses strictly to ('pending', 'pending_confirmation', 'confirmed', 'disputed')

-- 1. Drop existing constraint
ALTER TABLE public.matches 
  DROP CONSTRAINT IF EXISTS matches_status_check;

-- 2. Add tightened constraint
ALTER TABLE public.matches 
  ADD CONSTRAINT matches_status_check 
  CHECK (status IN ('pending', 'pending_confirmation', 'confirmed', 'disputed'));
