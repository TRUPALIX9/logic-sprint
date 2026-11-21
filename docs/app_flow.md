# App flow (1.1)

How LogicSprint fits together, drawn from the code. GitHub renders the Mermaid charts. Update them when a screen, a run state or the scoring changes.

## 1. Screens and navigation

```mermaid
flowchart TD
    Launch([App launch]) --> Splash["Splash<br/>rocket climbs the six game nodes<br/>syncs queued runs, loads boards"]
    Splash --> Shell

    subgraph Shell["Shell: bottom nav"]
        direction LR
        Ranks["Ranks<br/>Global Top 10 per game<br/>Refresh ▶ (rewarded)"]
        Play["Play (default)<br/>six game cards: name, best, type, icon<br/>Jump back in"]
        Profile["Profile<br/>name#code, Sprint Score gauge<br/>bests, History, Share"]
    end

    Play -- gear --> Settings["Settings<br/>sound, haptics, Music<br/>privacy choices, delete data"]
    Play -- hearts --> Hearts["Hearts sheet<br/>rewarded ad = +1 heart (max 5)"]
    Play -- card --> Sheet["Game sheet<br/>rules, best, difficulty or ship"]
    Sheet -- Start --> Run["Run screen<br/>one of six games"]
    Run -- game over --> Result["Game over<br/>score, best, next-run tip<br/>run saved / rank"]
    Result -- Play again --> Run
    Result -- Home --> Play
    Result -- Set name --> Name["Name sheet<br/>NAME#0000, find a free code"]
    Profile -- Set name / Edit --> Name
    Profile -- See all --> History["History"]
    Settings --> Privacy["Privacy policy"]
```

## 2. A run

Every game is a `RoundEngine` (`lib/games/round_engine.dart`) hosted by `RoundScreen`. Music follows the state: it plays only while the run is live.

```mermaid
stateDiagram-v2
    [*] --> ready
    ready --> playing: start
    playing --> paused: pause button, back button, app leaves screen
    paused --> playing: resume
    playing --> down: mistake (fail)
    down --> playing: revive with a heart or rewarded ad (up to 3)
    down --> resuming: revive with hold
    resuming --> playing: go
    down --> over: no revive left, offline, declined or 5 s timeout
    over --> [*]: Game over screen

    note right of playing
        Music: the game's own loop fades in
        +10 per correct, +20 every 5 in a row
    end note
    note right of down
        Music pauses (also while an ad plays)
    end note
```

## 3. Scores, boards and the Sprint Score

```mermaid
flowchart LR
    Run["Finished run"] --> Local["On the device<br/>best and time per game and difficulty<br/>History, plays"]
    Run --> Queue["Upload queue<br/>(kept while offline)"]
    Queue -->|record_run| Bests[("game_bests<br/>best, plays per player")]
    Bests --> Top["leaderboard_top / leaderboard_ranked<br/>score > 0, named players<br/>ties: shorter run (Memory Lane, Quick Math)<br/>or earlier best (others)"]
    Top -->|"once a day after 00:00 UTC<br/>or Refresh ▶"| RanksTab["Ranks tab"]
    Top --> Ratings[("player_ratings<br/>rebuilt 00:00 UTC by pg_cron")]
    Bests --> Ratings
    Ratings -->|my_rating| Gauge["Profile gauge<br/>Top X% in every band<br/>or Play more games to get your score"]
```

Sprint Score maths (same in `supabase/schema.sql` and `lib/models/sprint_rating.dart`):

1. Per board with 30+ players scoring above 0, your percentile, ordered like the board so equal scores get their own place. Easy is capped at 90 and Medium at 97 for the games with levels.
2. Per game you've played 3+ times, your best board.
3. R = (sum of game percentiles + 2 × 50) ÷ (games + 2).
4. Rating = R's percentile among players rated in 2+ games; shown as Top 1, 2, 5, 10, 15, 20, 25, then tens to 100, once 50+ players are rated.

## 4. Release

```mermaid
flowchart LR
    Code["Branch, make check"] --> Shots["Store screenshots<br/>integration_test/store_shots_test.dart<br/>framed in the launch kit"]
    Shots --> Docs["Listing copy, release notes,<br/>README, this file"]
    Docs --> DB["supabase/schema.sql<br/>applied to the live project"]
    DB --> Build["make build-aab / make build-ios"]
    Build --> Upload["Play Console, App Store Connect"]
    Upload --> Review["Review, manual release"]
    Review --> Site["logicsprint.trueorfalse.dev<br/>merge the site branch"]
```
