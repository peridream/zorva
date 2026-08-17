-- Migration 0011: Dynamic Trial Periods, Clean Plan IDs, and Monetization Controls
-- =================================================================================

-- 1. Ensure app_settings has all required keys for dynamic trials & monetization
INSERT INTO public.app_settings (key, value, description)
VALUES 
  ('monetization_enabled', 'false', 'Master switch for monetization: false = 100% Free Growth Mode, true = Paywall Active'),
  ('trial_duration_days', '365', 'Trial length in days assigned to new signups (365 in Growth Mode, 30 in Monetization Mode)'),
  ('founder_cap_per_city', '20', 'First X players per city who earn permanent gold FOUNDER badge and lifetime free flagship access'),
  ('flagship_annual_price_usd', '9.99', 'Annual subscription price for Flagship membership')
ON CONFLICT (key) DO UPDATE 
SET value = EXCLUDED.value, description = EXCLUDED.description;

-- 2. Update premium_subscriptions table schema & plan_id check constraint
ALTER TABLE public.premium_subscriptions 
  ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS current_period_end TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS is_founder BOOLEAN DEFAULT FALSE;

-- Update plan_id constraint to strictly allow the 4 canonical plans
ALTER TABLE public.premium_subscriptions 
  DROP CONSTRAINT IF EXISTS premium_subscriptions_plan_id_check;

ALTER TABLE public.premium_subscriptions 
  ADD CONSTRAINT premium_subscriptions_plan_id_check 
  CHECK (plan_id IN ('founder_flagship', 'flagship', 'community_trial', 'community'));

-- 3. Ensure profiles has is_founder column
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS is_founder BOOLEAN DEFAULT FALSE;
