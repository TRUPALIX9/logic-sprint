-- Global leaderboard for LogicSprint. Paste into the Supabase SQL editor and
-- run it (safe to run again). The app reads the top scores and inserts new
-- ones with the publishable key; RLS allows exactly that, and CHECK
-- constraints reject malformed rows.

create table if not exists public.leaderboard_scores (
  id uuid primary key default gen_random_uuid(),
  player_name text not null check (char_length(btrim(player_name)) between 1 and 20),
  score integer not null check (score > 0 and score <= 1000000),
  game_type text not null check (
    game_type in ('rocketLaunch', 'memoryLane', 'quickMath', 'guessColor')
  ),
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
  -- How long the run took; ties on score rank the shorter run higher.
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  app_version text not null default '' check (char_length(app_version) <= 20),
  created_at timestamptz not null default now()
);

-- For tables created by an earlier version of this script.
alter table public.leaderboard_scores
  add column if not exists duration_ms integer
  check (duration_ms is null or duration_ms >= 0);

-- Serves "top 10 for one game + difficulty", the only query the app runs.
drop index if exists leaderboard_scores_board_idx;
create index leaderboard_scores_board_idx
  on public.leaderboard_scores (game_type, difficulty, score desc, duration_ms);

alter table public.leaderboard_scores enable row level security;

drop policy if exists "Anyone can read scores" on public.leaderboard_scores;
create policy "Anyone can read scores"
  on public.leaderboard_scores for select
  to anon, authenticated
  using (true);

drop policy if exists "Anyone can submit a score" on public.leaderboard_scores;
create policy "Anyone can submit a score"
  on public.leaderboard_scores for insert
  to anon, authenticated
  with check (true);

-- No update/delete policies: submitted rows are immutable from the app.
grant select, insert on public.leaderboard_scores to anon, authenticated;
