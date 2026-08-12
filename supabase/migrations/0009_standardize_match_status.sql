-- Migration: Standardize matches status column to 'confirmed'
-- 1. Drop existing check constraint if it only allowed ('pending', 'verified', 'disputed')
ALTER TABLE public.matches 
  DROP CONSTRAINT IF EXISTS matches_status_check;

-- 2. Add updated check constraint including 'confirmed' and 'pending_confirmation'
ALTER TABLE public.matches 
  ADD CONSTRAINT matches_status_check 
  CHECK (status IN ('pending', 'pending_confirmation', 'confirmed', 'verified', 'disputed'));

-- 3. Update existing 'verified' rows to 'confirmed'
UPDATE public.matches 
  SET status = 'confirmed' 
  WHERE status = 'verified';
