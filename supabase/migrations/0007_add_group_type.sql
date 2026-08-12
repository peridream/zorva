-- Migration: Add group_type to groups table (community vs flagship)
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS group_type TEXT DEFAULT 'community';
