-- Migration: Create Community Groups and Group Members tables

CREATE TABLE IF NOT EXISTS public.groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    city TEXT DEFAULT 'Dallas',
    sport TEXT DEFAULT 'Table Tennis',
    invite_code VARCHAR(10) UNIQUE NOT NULL,
    creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    max_members INT DEFAULT 20,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

-- Enable RLS
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

-- Permissive RLS policies for Zorva app
CREATE POLICY "Allow public read access to groups" ON public.groups FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert to groups" ON public.groups FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow authenticated update to groups" ON public.groups FOR UPDATE USING (true);
CREATE POLICY "Allow authenticated delete to groups" ON public.groups FOR DELETE USING (true);

CREATE POLICY "Allow public read access to group_members" ON public.group_members FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert to group_members" ON public.group_members FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow authenticated update to group_members" ON public.group_members FOR UPDATE USING (true);
CREATE POLICY "Allow authenticated delete to group_members" ON public.group_members FOR DELETE USING (true);
