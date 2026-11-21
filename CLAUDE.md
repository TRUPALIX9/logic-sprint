# Logic Sprint

Flutter brain-games app (iOS + Android). Endless runs, one mistake ends a run,
up to 3 revives (heart or rewarded ad), Supabase leaderboards, AdMob ads.

## Commands

- `make check`: `flutter analyze` + `flutter test` (same as CI and the pre-push hook)
- `flutter build ios --simulator --debug`: then launch `build/ios/iphonesimulator/Runner.app`
- `make run-android`: Android emulator
- Release builds need `config/admob.json` (see `config/admob.example.json`)

## How the code is laid out

- `lib/games/round_engine.dart`: base `RoundEngine` (run, pause, down, revive, get-ready
  `resuming`, finish). Every game engine subclasses it; `RoundScreen` hosts it.
- `lib/games/<game>/`: one folder per game (engine + screen/board).
- `lib/models/game.dart`: `GameId` (titles, skills, accents, difficulty support). Add new games
  **last** so stored keys don't shift, and allow the name in `supabase/schema.sql` before release.
- `lib/core/theme.dart` (`LS`, `LSText`) and `lib/ui/chamfer.dart`: the "Circuit Noir" look.
  Chamfered corners only, never rounded. Fonts: Rajdhani, IBM Plex Sans, JetBrains Mono.
- Plans and mockups: `design/plans/*.html`. Game ideas backlog: `docs/ideas.md`.

## Rules

- State is Provider + `ChangeNotifier`. Don't add Riverpod/BLoC/GoRouter/Dio/Freezed without a decision.
- Respect reduce motion (`MediaQuery.disableAnimationsOf`), but never shorten play-critical
  timers: use `AnimationBehavior.preserve`.
- Engines stay pure and are tested with `fake_async`. An `AnimationController` completes on the
  first frame after its duration, so pump `duration + one frame` in widget tests.
- Work on a branch, never commit straight to `production`.

## Skills and agents (from skills.trueorfalse.dev)

| Item | Type | Use when |
|---|---|---|
| `dart-flutter-patterns` | skill | writing or reviewing Dart/Flutter code |
| `motion` | skill | adding or reviewing animation |
| `accessibility` | skill | building interactive UI, before shipping a screen |
| `ui-hig` | skill | designing a screen, sizing tap targets, a layout that "feels off" |
| `vet-third-party` | skill | before adding a new package, skill or MCP server |
| `flutter-expert` | agent | Flutter architecture or larger UI work |
