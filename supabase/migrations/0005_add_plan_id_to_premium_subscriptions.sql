-- Migration: Add plan_id column and update status check constraint on premium_subscriptions
-- ============================================================

ALTER TABLE premium_subscriptions 
  ADD COLUMN IF NOT EXISTS plan_id text NOT NULL DEFAULT 'community_trial';

-- Update existing check constraint on status to strictly allow ('active', 'expired')
ALTER TABLE premium_subscriptions 
  DROP CONSTRAINT IF EXISTS premium_subscriptions_status_check;

ALTER TABLE premium_subscriptions 
  ADD CONSTRAINT premium_subscriptions_status_check 
  CHECK (status IN ('active', 'expired'));

-- RLS Policy
ALTER TABLE premium_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public allow all premium_subscriptions" 
  ON premium_subscriptions 
  FOR ALL 
  USING (true) 
  WITH CHECK (true);
