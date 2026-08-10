-- Auto-generated per-sport views.
--
-- Goal: keep "add a sport = one INSERT into sports" true, while still
-- giving you clean, separately-browsable views like table_tennis_matches
-- and table_tennis_ratings in the Supabase Table Editor and in queries.
--
-- How it works: a trigger fires whenever a new row is inserted into
-- `sports`, and dynamically creates two views for that sport's slug.
-- Nothing needs to be hand-written per sport ever again.

create or replace function create_sport_views()
returns trigger as $$
begin
  execute format(
    'create or replace view %I_matches as
       select * from matches where sport_id = %L',
    new.slug, new.id
  );

  execute format(
    'create or replace view %I_ratings as
       select pcr.*, rc.type as context_type, rc.name as context_name
       from player_context_ratings pcr
       join rating_contexts rc on rc.id = pcr.context_id
       where rc.sport_id = %L',
    new.slug, new.id
  );

  return new;
end;
$$ language plpgsql;

create trigger trg_create_sport_views
  after insert on sports
  for each row execute function create_sport_views();

-- Backfill views for sports that already exist (Table Tennis, seeded
-- in the original migration, was inserted before this trigger existed)
do $$
declare
  s record;
begin
  for s in select * from sports loop
    execute format(
      'create or replace view %I_matches as
         select * from matches where sport_id = %L',
      s.slug, s.id
    );
    execute format(
      'create or replace view %I_ratings as
         select pcr.*, rc.type as context_type, rc.name as context_name
         from player_context_ratings pcr
         join rating_contexts rc on rc.id = pcr.context_id
         where rc.sport_id = %L',
      s.slug, s.id
    );
  end loop;
end $$;