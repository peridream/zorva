-- Migration 0010: Growth-First Monetization Controls, App Settings, and Founder Flags

-- 1. Create app_settings control panel table
CREATE TABLE IF NOT EXISTS public.app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for app_settings (public read, service role write)
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public allow read app_settings" ON public.app_settings;
CREATE POLICY "Public allow read app_settings" ON public.app_settings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public allow write app_settings" ON public.app_settings;
CREATE POLICY "Public allow write app_settings" ON public.app_settings FOR ALL USING (true) WITH CHECK (true);

-- Seed default settings for Growth Mode (monetization_enabled = false)
INSERT INTO public.app_settings (key, value, description)
VALUES 
  ('monetization_enabled', 'false', 'Master switch for monetization: false = 100% Free Growth Mode, true = Paywall Active'),
  ('growth_phase_duration_days', '365', 'Number of days of full access granted to early signups'),
  ('founder_cap_per_city', '20', 'First X players per city who earn permanent gold FOUNDER badge'),
  ('flagship_annual_price_usd', '9.99', 'Annual subscription price for Flagship membership'),
  ('group_one_time_fee_usd', '4.99', 'One-time fee to create/host a group after Year 1'),
  ('announcement_banner_enabled', 'false', 'Master switch for top dashboard announcement banner'),
  ('announcement_banner_text', '', 'Text displayed in top announcement banner when enabled')
ON CONFLICT (key) DO NOTHING;

-- 2. Add is_founder flag to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_founder BOOLEAN DEFAULT FALSE;

-- 3. Add is_founder and grandfathered_until to premium_subscriptions
ALTER TABLE public.premium_subscriptions 
ADD COLUMN IF NOT EXISTS is_founder BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS grandfathered_until TIMESTAMP WITH TIME ZONE;
