-- LogicSprint backend: one profile per player, one best per game and
-- difficulty, a public Top 10 view and aggregate stats.
--
-- Setup (Supabase dashboard):
--   1. Authentication → Sign In / Providers → enable "Allow anonymous sign-ins".
--   2. SQL Editor → paste this file → Run. Safe to run again.
--
-- Every phone signs in anonymously (no login screen), so auth.uid() is the
-- player. Tables are read-only to clients; all writes go through the
-- functions below, which only ever touch the caller's own rows.

-- Replaced by game_bests (it never went live).
drop table if exists public.leaderboard_scores;

-- ---------------------------------------------------------------- tables --

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (
    display_name is null or display_name ~ '^[A-Za-z0-9 _-]{1,20}$'
  ),
  created_at timestamptz not null default now()
);

-- Display names are unique regardless of case.
create unique index if not exists profiles_display_name_key
  on public.profiles (lower(display_name));

create table if not exists public.game_bests (
  player_id uuid not null references public.profiles (id) on delete cascade,
  game_type text not null check (
    game_type in ('rocketLaunch', 'memoryLane', 'quickMath', 'guessColor')
  ),
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
  best_score integer not null default 0 check (best_score between 0 and 1000000),
  best_duration_ms integer check (best_duration_ms is null or best_duration_ms >= 0),
  best_at timestamptz,
  plays integer not null default 0 check (plays >= 0),
  last_played_at timestamptz not null default now(),
  primary key (player_id, game_type, difficulty)
);

-- Serves "top 10 for one game + difficulty" and rank lookups.
create index if not exists game_bests_board_idx
  on public.game_bests (game_type, difficulty, best_score desc, best_duration_ms);

-- ------------------------------------------------------------------ rls --

alter table public.profiles enable row level security;
alter table public.game_bests enable row level security;

-- Names and bests are public (they appear on the leaderboard).
drop policy if exists "Profiles are public" on public.profiles;
create policy "Profiles are public"
  on public.profiles for select to anon, authenticated using (true);

drop policy if exists "Bests are public" on public.game_bests;
create policy "Bests are public"
  on public.game_bests for select to anon, authenticated using (true);

-- No insert/update/delete policies: writes only through the functions below.
grant select on public.profiles, public.game_bests to anon, authenticated;

-- -------------------------------------------------------------- functions --

-- Sets or changes the caller's display name. Raises 'name_taken',
-- 'invalid_name' or 'not_signed_in'.
create or replace function public.claim_name(p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(p_name);
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  if v_name !~ '^[A-Za-z0-9 _-]{1,20}$' then
    raise exception 'invalid_name';
  end if;
  begin
    insert into profiles (id, display_name)
    values (auth.uid(), v_name)
    on conflict (id) do update set display_name = excluded.display_name;
  exception when unique_violation then
    raise exception 'name_taken';
  end;
end;
$$;

-- Records one finished run for the caller: +1 play, and the best changes if
-- the score is higher, or (Memory Lane / Quick Math only) equal in less time.
-- Rocket Launch and Guess Color don't track time: their duration is dropped,
-- so an equal score never replaces the earlier best.
create or replace function public.record_run(
  p_game text,
  p_difficulty text,
  p_score integer,
  p_duration_ms integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;

  if p_game not in ('memoryLane', 'quickMath') then
    p_duration_ms := null;
  end if;

  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;

  insert into game_bests as g (
    player_id, game_type, difficulty, best_score, best_duration_ms, best_at, plays
  )
  values (
    auth.uid(), p_game, p_difficulty, greatest(p_score, 0), p_duration_ms, now(), 1
  )
  on conflict (player_id, game_type, difficulty) do update set
    plays = g.plays + 1,
    last_played_at = now(),
    best_score = case when (excluded.best_score, -coalesce(excluded.best_duration_ms, 2147483647))
                         > (g.best_score, -coalesce(g.best_duration_ms, 2147483647))
                      then excluded.best_score else g.best_score end,
    best_duration_ms = case when (excluded.best_score, -coalesce(excluded.best_duration_ms, 2147483647))
                               > (g.best_score, -coalesce(g.best_duration_ms, 2147483647))
                            then excluded.best_duration_ms else g.best_duration_ms end,
    best_at = case when (excluded.best_score, -coalesce(excluded.best_duration_ms, 2147483647))
                      > (g.best_score, -coalesce(g.best_duration_ms, 2147483647))
                   then now() else g.best_at end;
end;
$$;

revoke execute on function public.claim_name(text) from public, anon;
revoke execute on function public.record_run(text, text, integer, integer) from public, anon;
grant execute on function public.claim_name(text) to authenticated;
grant execute on function public.record_run(text, text, integer, integer) to authenticated;

-- ------------------------------------------------------------------ views --

-- The Top 10 source (named leaderboard_top so it never collides with an
-- existing "leaderboard" table): named players with a score, ranked by score,
-- then by tie_key (lower wins): the shorter run for Memory Lane and Quick Math,
-- the earlier best for Rocket Launch and Guess Color. tie_key is only ever
-- compared within one board, so the two units never mix.
create or replace view public.leaderboard_top
with (security_invoker = true) as
select
  g.player_id,
  p.display_name as player_name,
  g.game_type,
  g.difficulty,
  g.best_score as score,
  case when g.game_type in ('memoryLane', 'quickMath')
       then g.best_duration_ms end as duration_ms,
  g.best_at,
  case when g.game_type in ('memoryLane', 'quickMath')
       then coalesce(g.best_duration_ms, 2147483647)::bigint
       else (extract(epoch from g.best_at) * 1000)::bigint end as tie_key
from public.game_bests g
join public.profiles p on p.id = g.player_id
where g.best_score > 0 and p.display_name is not null;

-- The caller's position on one board (null if they haven't scored there or
-- haven't claimed a name yet).
create or replace function public.my_rank(p_game text, p_difficulty text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select 1 + (
    select count(*)::integer
    from leaderboard_top l
    where l.game_type = p_game
      and l.difficulty = p_difficulty
      and (l.score > me.score
           or (l.score = me.score and l.tie_key < me.tie_key))
  )
  from leaderboard_top me
  where me.player_id = auth.uid()
    and me.game_type = p_game
    and me.difficulty = p_difficulty;
$$;

revoke execute on function public.my_rank(text, text) from public, anon;
grant execute on function public.my_rank(text, text) to authenticated;

-- Public per-player stats ("John Doe · Quick Math best 480 · played 37"),
-- e.g. for the products page.
create or replace view public.player_stats
with (security_invoker = true) as
select
  p.display_name as player_name,
  g.game_type,
  g.difficulty,
  g.best_score,
  g.best_duration_ms,
  g.plays,
  g.last_played_at
from public.game_bests g
join public.profiles p on p.id = g.player_id
where p.display_name is not null;

-- Public totals per game: players, plays and the top score.
create or replace view public.game_stats
with (security_invoker = true) as
select
  game_type,
  count(distinct player_id)::integer as players,
  sum(plays)::integer as plays,
  max(best_score) as top_score
from public.game_bests
group by game_type;

grant select on public.leaderboard_top, public.player_stats, public.game_stats
  to anon, authenticated;
