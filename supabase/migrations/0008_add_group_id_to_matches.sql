-- Migration: Add group_id column to matches table for automatic group match tagging
ALTER TABLE public.matches 
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL;
