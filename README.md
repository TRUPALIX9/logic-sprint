# LogicSprint: Brain Games

**LogicSprint** is a free Flutter brain-training app for Android: four quick games, personal bests on the device, and an optional global Top 10 per game. No login. Ad-supported via Google AdMob.

| | |
|---|---|
| **Version** | 1.0.0 |
| **Platform** | Android (Google Play); iOS later |
| **Stack** | Flutter 3.x, Dart 3.11+ |
| **Storage** | `shared_preferences` on the device; Supabase for the leaderboard |

---

## Games

Every round lasts 30 seconds (the clock is never shown). +10 per correct action, plus a hidden +20 bonus every 5-in-a-row.

| Game | Skill | How it plays | Difficulty |
|------|-------|--------------|------------|
| **Rocket Launch** | Reflex | Touch and drag anywhere to steer through an asteroid field; hits cost 15 points | Ramps from calm to meteor storm |
| **Memory Lane** | Memory | Tiles flash in sequence; tap them back in order, one more tile each level | Easy 3×3 · Medium 4×4 · Hard 5×5 |
| **Quick Math** | Arithmetic | Tap the right answer of four | Easy + − · Medium + − × · Hard + − × ÷ |
| **Guess Color** | Focus | Tap the ink color, not the word (Stroop) | Ramps from 4 colors to 6, then shuffled buttons |

---

## App structure

Bottom nav: **Ranks · Play · Profile** (Play in the middle, the default). Settings opens from the gear on Play.

```text
lib/
  main.dart, app.dart        # bootstrap, providers, NavTabs
  core/                      # theme (Circuit Noir palette + fonts), config
  models/                    # GameId, Difficulty, RoundResult, LeaderboardEntry
  services/                  # storage, leaderboard (Supabase), ads (AdMob + UMP)
  state/app_state.dart       # settings, bests, haptic/sound feedback
  ui/                        # chamfered UI kit, logo, game bar, ad banner
  games/                     # RoundEngine + RoundScreen, one folder per game
  screens/                   # splash, shell tabs, game sheet, result, settings, privacy
test/                        # engine, leaderboard, model and app smoke tests
assets/fonts/                # Rajdhani, IBM Plex Sans, JetBrains Mono (OFL, licenses included)
assets/brand/                # launcher icon, store icon + feature graphic, policy, listing copy
design/wireframes/           # design canvas source (.dc.html)
supabase/schema.sql          # leaderboard table, RLS, index
config/admob.example.json    # AdMob config template (real config is gitignored)
```

Each game is an engine (`RoundEngine` subclass: pure logic, unit-tested with `fake_async`) plus a screen hosted by `RoundScreen`, which runs the round, saves the best, shows the between-round ad and opens Result.

---

## Getting started

```bash
make setup
make emulator    # optional
make run
```

Debug builds use Google's AdMob test IDs automatically.

```bash
make check       # flutter analyze + flutter test (same as CI)
```

After changing icon PNGs: `dart run flutter_launcher_icons`.

---

## Release builds

Release builds need two gitignored files:

- `android/key.properties` + upload keystore — [docs/android_release_signing.md](docs/android_release_signing.md)
- `config/admob.json` — copy [config/admob.example.json](config/admob.example.json) and fill in your AdMob IDs

```bash
make build-aab
```

Gradle refuses release builds without `ADMOB_APP_ID`, and bundles without a release keystore. Full steps: [docs/release_checklist.md](docs/release_checklist.md)

---

## Leaderboard

- One Top 10 per game (and per difficulty for Memory Lane and Quick Math), queried server-side
- Post from the Result screen only; 5 posts per device per day
- Each board cached 10 minutes; manual refresh has a 60 s cooldown; requests time out after 8 s
- Fully playable offline

Setup: run [supabase/schema.sql](supabase/schema.sql) in the Supabase SQL editor. The publishable key in `lib/core/config.dart` is safe to ship; RLS limits it to read and insert.

---

## Ads

AdMob banner on the Play tab and an interstitial after every 2nd round. Consent is gathered with Google's UMP SDK before any ad request; users in consent regions get **Privacy choices** in Settings.

---

## Git workflow

`production` is the main branch: commit and push there directly (CI runs analyze + test on every push). Push a `vX.Y.Z` tag to build the signed store release. See [docs/git_workflow.md](docs/git_workflow.md).

## Store screenshots

Rendered from the real screens (1080×2400, bundled fonts), no emulator needed:

```bash
SCREENSHOTS=1 ICONS_FONT="$(dirname "$(readlink -f "$(which flutter)")")/cache/artifacts/material_fonts/MaterialIcons-Regular.otf" \
  flutter test test/store_screenshots_test.dart
```

Output: `assets/brand/store/screenshots/*.png`.

## License

Private project (`publish_to: none`). Bundled fonts are under the SIL Open Font License; see `assets/fonts/*-OFL.txt`.
