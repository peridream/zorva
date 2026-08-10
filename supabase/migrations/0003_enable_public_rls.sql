-- Migration 0003: Enable RLS Policies for Public/Anon Client Access
-- Target: Supabase Postgres

alter table users enable row level security;
alter table sports enable row level security;
alter table rating_contexts enable row level security;
alter table player_context_ratings enable row level security;
alter table matches enable row level security;
alter table match_confirmations enable row level security;
alter table match_context_links enable row level security;
alter table flagship_unlocks enable row level security;

drop policy if exists "Public allow all users" on users;
create policy "Public allow all users" on users for all using (true) with check (true);

drop policy if exists "Public allow all sports" on sports;
create policy "Public allow all sports" on sports for all using (true) with check (true);

drop policy if exists "Public allow all rating_contexts" on rating_contexts;
create policy "Public allow all rating_contexts" on rating_contexts for all using (true) with check (true);

drop policy if exists "Public allow all player_context_ratings" on player_context_ratings;
create policy "Public allow all player_context_ratings" on player_context_ratings for all using (true) with check (true);

drop policy if exists "Public allow all matches" on matches;
create policy "Public allow all matches" on matches for all using (true) with check (true);

drop policy if exists "Public allow all match_confirmations" on match_confirmations;
create policy "Public allow all match_confirmations" on match_confirmations for all using (true) with check (true);

drop policy if exists "Public allow all match_context_links" on match_context_links;
create policy "Public allow all match_context_links" on match_context_links for all using (true) with check (true);

drop policy if exists "Public allow all flagship_unlocks" on flagship_unlocks;
create policy "Public allow all flagship_unlocks" on flagship_unlocks for all using (true) with check (true);
