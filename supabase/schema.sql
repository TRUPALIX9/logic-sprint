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

-- Every name carries a 4-digit tag ("NEON_FOX#0420"), so many players can
-- share a name: only name + tag is unique (the name ignoring case).
alter table public.profiles
  add column if not exists tag smallint check (tag is null or tag between 0 and 9999);

-- Players who named themselves before tags existed get a random one; their
-- names were unique, so no two can clash.
update public.profiles
  set tag = floor(random() * 10000)::smallint
  where tag is null and display_name is not null;

drop index if exists public.profiles_display_name_key;
create unique index if not exists profiles_name_tag_key
  on public.profiles (lower(display_name), tag);

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

-- Moderation: a name reported by enough players is hidden from the boards
-- until the player picks another name (or you clear it in the dashboard).
alter table public.profiles
  add column if not exists hidden boolean not null default false;

create table if not exists public.name_reports (
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  player_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reporter_id, player_id)
);

-- Words a name may not contain, lower case. Checked by claim_name after
-- folding look-alikes (0→o, 1→i, 3→e, 4→a, 5→s, 7→t, @→a, $→s) and
-- dropping spaces, _ and -. Substring match, so avoid short words that hide
-- inside ordinary ones ("grape", "analyst"). Add rows in the dashboard; no
-- client reads it.
create table if not exists public.banned_words (
  word text primary key check (word = lower(word) and word ~ '^[a-z]+$')
);

insert into public.banned_words (word) values
  ('fuck'), ('fuk'), ('shit'), ('cunt'), ('bitch'), ('whore'), ('slut'),
  ('dick'), ('cock'), ('pussy'), ('penis'), ('vagina'), ('porn'),
  ('rapist'), ('nazi'), ('hitler'), ('nigger'), ('nigga'), ('faggot'),
  ('retard'), ('tranny'), ('kike'), ('chink'), ('wetback'), ('asshole'),
  ('bastard'), ('motherf'), ('wank'), ('twat'), ('dildo'), ('kkk')
on conflict do nothing;

-- Serves "top 10 for one game + difficulty" and rank lookups.
create index if not exists game_bests_board_idx
  on public.game_bests (game_type, difficulty, best_score desc, best_duration_ms);

-- ------------------------------------------------------------------ rls --

alter table public.profiles enable row level security;
alter table public.game_bests enable row level security;
-- No policies and no grants: only the functions below touch these.
alter table public.name_reports enable row level security;
alter table public.banned_words enable row level security;
revoke all on public.name_reports, public.banned_words from anon, authenticated;

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

-- A random tag nobody else uses with this name (case-insensitive), or null
-- if all 10 000 are gone. The caller's own current tag counts as free.
create or replace function public.free_tag(p_name text)
returns integer
language sql
volatile
security definer
set search_path = public
as $$
  select t
  from generate_series(0, 9999) t
  where not exists (
    select 1 from profiles p
    where lower(p.display_name) = lower(btrim(p_name))
      and p.tag = t
      and p.id is distinct from auth.uid()
  )
  order by random()
  limit 1;
$$;

-- True when [p_name] contains a banned word (see banned_words).
create or replace function public.name_is_banned(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from banned_words b
    where position(
      b.word in translate(lower(p_name), '013457@$ _-', 'oieastas')
    ) > 0
  );
$$;

-- Sets or changes the caller's name and tag. Raises 'name_taken' (that
-- name + tag belongs to someone else), 'name_not_allowed' (a banned word),
-- 'invalid_name', 'invalid_tag' or 'not_signed_in'. A new name starts
-- clean: its old reports are dropped and it shows on the boards again.
create or replace function public.claim_name(p_name text, p_tag integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(p_name);
  v_old text;
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  if v_name !~ '^[A-Za-z0-9 _-]{1,20}$' then
    raise exception 'invalid_name';
  end if;
  if p_tag is null or p_tag not between 0 and 9999 then
    raise exception 'invalid_tag';
  end if;
  if name_is_banned(v_name) then
    raise exception 'name_not_allowed';
  end if;
  select display_name into v_old from profiles where id = auth.uid();
  begin
    insert into profiles (id, display_name, tag)
    values (auth.uid(), v_name, p_tag)
    on conflict (id) do update
      set display_name = excluded.display_name, tag = excluded.tag;
  exception when unique_violation then
    raise exception 'name_taken';
  end;
  -- Reports were about the old name (a new code alone keeps them).
  if v_old is distinct from v_name then
    delete from name_reports where player_id = auth.uid();
    update profiles set hidden = false where id = auth.uid();
  end if;
end;
$$;

-- Builds from before tags: keep working by picking a free tag for them.
create or replace function public.claim_name(p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tag integer := public.free_tag(p_name);
begin
  if v_tag is null then
    raise exception 'name_taken';
  end if;
  perform public.claim_name(p_name, v_tag);
end;
$$;

-- Records one finished run for the caller: +1 play, and the best changes if
-- the score is higher, or (Memory Lane / Quick Math only) equal in less time.
-- Rocket Launch and Guess Color don't track time: their duration is dropped,
-- so an equal score never replaces the earlier best.
--
-- A score no real run could reach still counts as a play but never becomes
-- a best (no error: the app would retry a refused run forever). Real runs
-- earn at most about 14 points per correct answer (10, plus 20 every 5 in a
-- row), and no answer takes under 280 ms, so timed games stay under
-- 60 points a second; the untimed games are capped well above the best
-- runs seen (Rocket Launch tops out near 10 000).
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

  if p_game in ('memoryLane', 'quickMath') then
    if p_duration_ms is null or p_duration_ms < 0
       or p_score > 100 + p_duration_ms::bigint * 60 / 1000 then
      p_score := 0;
    end if;
  else
    p_duration_ms := null;
    if p_score > 50000 then
      p_score := 0;
    end if;
  end if;
  p_score := least(greatest(p_score, 0), 1000000);

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

-- Reports another player's name. Three different reporters hide it from
-- the boards (it comes back when they pick another name). Reporting
-- yourself, an unnamed player or someone twice does nothing.
create or replace function public.report_name(p_player uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  if p_player = auth.uid()
     or not exists (select 1 from profiles where id = p_player and display_name is not null) then
    return;
  end if;
  insert into profiles (id) values (auth.uid()) on conflict (id) do nothing;
  insert into name_reports (reporter_id, player_id)
  values (auth.uid(), p_player)
  on conflict do nothing;
  update profiles set hidden = true
  where id = p_player
    and (select count(*) from name_reports where player_id = p_player) >= 3;
end;
$$;

-- Deletes the caller's account: the anonymous auth user, their profile,
-- bests and reports (cascades). The app then signs in as a new player.
create or replace function public.delete_my_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.name_is_banned(text) from public, anon, authenticated;
revoke execute on function public.report_name(uuid) from public, anon;
revoke execute on function public.delete_my_data() from public, anon;
grant execute on function public.report_name(uuid) to authenticated;
grant execute on function public.delete_my_data() to authenticated;
revoke execute on function public.claim_name(text) from public, anon;
revoke execute on function public.claim_name(text, integer) from public, anon;
revoke execute on function public.free_tag(text) from public, anon;
revoke execute on function public.record_run(text, text, integer, integer) from public, anon;
grant execute on function public.claim_name(text) to authenticated;
grant execute on function public.claim_name(text, integer) to authenticated;
grant execute on function public.free_tag(text) to authenticated;
grant execute on function public.record_run(text, text, integer, integer) to authenticated;

-- ------------------------------------------------------------------ views --

-- The Top 10 source (named leaderboard_top so it never collides with an
-- existing "leaderboard" table): named players with a score, ranked by score,
-- then by tie_key (lower wins): the shorter run for Memory Lane and Quick Math,
-- the earlier best for Rocket Launch and Guess Color. tie_key is only ever
-- compared within one board, so the two units never mix. player_name
-- includes the tag: "NEON_FOX#0420".
create or replace view public.leaderboard_top
with (security_invoker = true) as
select
  g.player_id,
  p.display_name || '#' || lpad(coalesce(p.tag, 0)::text, 4, '0') as player_name,
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
where g.best_score > 0 and p.display_name is not null and not p.hidden;

-- Every board at once, each row with its position (ties share a rank, as
-- in my_rank). The app fetches board_rank <= 10 for all boards in one
-- request once per UTC day, plus its own rows for the ranks.
create or replace view public.leaderboard_ranked
with (security_invoker = true) as
select
  l.*,
  rank() over (
    partition by l.game_type, l.difficulty
    order by l.score desc, l.tie_key asc
  )::integer as board_rank
from public.leaderboard_top l;

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
  p.display_name || '#' || lpad(coalesce(p.tag, 0)::text, 4, '0') as player_name,
  g.game_type,
  g.difficulty,
  g.best_score,
  g.best_duration_ms,
  g.plays,
  g.last_played_at
from public.game_bests g
join public.profiles p on p.id = g.player_id
where p.display_name is not null and not p.hidden;

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

grant select on public.leaderboard_top, public.leaderboard_ranked,
  public.player_stats, public.game_stats
  to anon, authenticated;
