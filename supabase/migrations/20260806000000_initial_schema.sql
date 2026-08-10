-- ====================================================================
-- ZORVA SPORTS PASSPORT - GUARANTEED IDEMPOTENT MIGRATION SCHEMA
-- ====================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------------------
-- 2. DROP OLD/LEGACY TEST TABLES (Fixes missing creator_id column error)
-- --------------------------------------------------------------------
DROP TABLE IF EXISTS public.matches CASCADE;
DROP TABLE IF EXISTS public.city_rankings CASCADE;

-- --------------------------------------------------------------------
-- 3. CREATE TABLES (Clean Zorva Passport Schema)
-- --------------------------------------------------------------------

-- A. PROFILES TABLE (Player Identity & Glicko-2 Ratings)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  phone TEXT,
  full_name TEXT,
  username TEXT UNIQUE,
  avatar_url TEXT,
  primary_sport TEXT DEFAULT 'Tennis',
  city TEXT,
  glicko_rating DOUBLE PRECISION DEFAULT 1500.0,
  rating_deviation DOUBLE PRECISION DEFAULT 350.0,
  volatility DOUBLE PRECISION DEFAULT 0.06,
  matches_played INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- B. MATCHES TABLE (Sub-15s Logger & Verifications)
CREATE TABLE public.matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  opponent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  sport TEXT NOT NULL DEFAULT 'Tennis',
  creator_score INTEGER NOT NULL,
  opponent_score INTEGER NOT NULL,
  winner_id UUID REFERENCES public.profiles(id),
  status TEXT CHECK (status IN ('pending', 'verified', 'disputed')) DEFAULT 'pending',
  rating_change_creator DOUBLE PRECISION DEFAULT 0.0,
  rating_change_opponent DOUBLE PRECISION DEFAULT 0.0,
  logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- C. CITY RANKINGS TABLE
CREATE TABLE public.city_rankings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city TEXT NOT NULL,
  sport TEXT NOT NULL,
  player_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  city_rank INTEGER NOT NULL,
  glicko_rating DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(city, sport, player_id)
);

-- --------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY POLICIES
-- --------------------------------------------------------------------

-- Profiles RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;

CREATE POLICY "Public profiles are viewable by everyone" 
  ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile" 
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Matches RLS
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Matches are viewable by everyone" ON public.matches;
DROP POLICY IF EXISTS "Authenticated users can log matches" ON public.matches;
DROP POLICY IF EXISTS "Participants can update match verification status" ON public.matches;

CREATE POLICY "Matches are viewable by everyone" 
  ON public.matches FOR SELECT USING (true);

CREATE POLICY "Authenticated users can log matches" 
  ON public.matches FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Participants can update match verification status" 
  ON public.matches FOR UPDATE USING (
    auth.uid() = creator_id OR auth.uid() = opponent_id
  );

-- City Rankings RLS
ALTER TABLE public.city_rankings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "City rankings are viewable by everyone" ON public.city_rankings;

CREATE POLICY "City rankings are viewable by everyone" 
  ON public.city_rankings FOR SELECT USING (true);

-- --------------------------------------------------------------------
-- 5. AUTOMATIC SIGNUP TRIGGER (Auto-Creates Profile on Auth Signup)
-- --------------------------------------------------------------------
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, phone)
  VALUES (new.id, new.email, new.phone)
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
