-- Migration 0014: Add seen_milestones array column to public.profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS seen_milestones text[] DEFAULT '{}'::text[];

COMMENT ON COLUMN public.profiles.seen_milestones IS 'List of milestone identifiers already celebrated by the user (e.g. welcome, milestone_10, milestone_20)';
