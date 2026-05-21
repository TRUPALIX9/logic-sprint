# LogicSprint: Brain Games

**LogicSprint** is a free, offline Flutter brain-training app for **Android** and **iOS**. Play fast 30-second mini-games, chase local high scores, and practice logic, math, and focus — no account, no internet, no ads.

| | |
|---|---|
| **Version** | 1.0.0 |
| **Platform** | Android, iOS |
| **Stack** | Flutter 3.x, Dart 3.12+ |
| **Storage** | `shared_preferences` (device only) |

---

## Mini-games (v1)

| Game | Description |
|------|-------------|
| **Quick Math** | Addition, subtraction, multiplication, and division by difficulty |
| **Number Sequence** | Spot the pattern and pick the next number |
| **True or False** | Math, shape, and number facts — true or false |

Each round lasts **30 seconds**. Correct answers add **+10** points; **5 correct in a row** awards a **+20** streak bonus. High scores are saved per game and difficulty (Easy / Medium / Hard).

**Coming soon:** Memory Pattern, Color Confusion, Tap in Order, Odd One Out, Word Scramble.

---

## Brand assets

Official artwork lives under **`assets/brand/`** (original concept crops — not redrawn). The app and store listings should use these files, not ad-hoc copies.

### Folder layout

```text
assets/brand/
  icons/                    # Launcher + adaptive icons
  logos/png/                # In-app logos and lockups
  tokens/brand_tokens.json  # Canonical colors & app name
  docs/                     # Privacy policy & store listing copy
  store/google_play/        # Play Store icon & feature graphic
  games/                    # Per-game tiles (drop PNGs here when ready)
  logicsprint/              # Full mood board (reference only)
```

### Recommended files

| Use case | Asset path |
|----------|------------|
| Launcher / app icon | `icons/app_icon_1024.png` |
| Android adaptive icon | `icons/android/adaptive_icon_foreground.png` + `adaptive_icon_background.png` |
| Play Store icon | `store/google_play/play_store_icon_512.png` |
| Play feature graphic | `store/google_play/feature_graphic_1024x500.png` |
| In-app mark (splash, about) | `logos/png/logo_mark_original_transparent.png` |
| Hero / splash (dark background) | `logos/png/horizontal_lockup_white.png` |
| Light surfaces | `logos/png/horizontal_lockup_dark.png` |
| Brand colors | `tokens/brand_tokens.json` |
| Privacy policy text | `docs/privacy_policy.md` |
| Store listing copy | `docs/store_listing.md` |

**Reference only (do not use in production UI):**

- `logicsprint/brand_kit_master.png` — full brand board
- `logos/png/original_*_crop.png` — early crops; superseded by cleaned PNGs above

### Brand colors

From `assets/brand/tokens/brand_tokens.json`:

| Token | Hex |
|-------|-----|
| Midnight Purple | `#12002F` |
| Deep Blue | `#004F9F` |
| Electric Blue | `#23BEEF` |
| Sprint Orange | `#FC8620` |
| Soft Ice | `#D8E5EC` |
| Ink | `#130A33` |

### In-app integration

| Code | Role |
|------|------|
| `lib/core/brand/brand_assets.dart` | Single source of asset paths |
| `lib/core/brand/brand_palette.dart` | Theme colors from tokens |
| `lib/core/brand/game_brand.dart` | Per-game accent gradients |
| `lib/widgets/brand_logo.dart` | `BrandLogo` widget (mark / lockups) |
| `lib/services/brand_content_service.dart` | Loads privacy & store markdown |

Regenerate Android/iOS launcher icons after changing icon PNGs:

```bash
dart run flutter_launcher_icons
```

More detail: [assets/brand/README.md](assets/brand/README.md), [docs/brand_assets.md](docs/brand_assets.md).

---

## Project structure

```text
lib/
  main.dart, app.dart
  core/           # theme, routes, game engine, brand, utils
  models/         # game, question, score
  services/       # storage, sound, app state, brand content
  screens/        # splash, home, games, settings, about, …
  widgets/        # buttons, cards, brand logo, timer, …
test/             # question generator unit tests
assets/brand/     # brand kit (see above)
docs/             # epic plan, release checklist, git workflow
```

---

## Getting started

**Requirements:** Flutter SDK 3.x, Xcode (iOS), Android SDK (Android).

```bash
git clone https://github.com/TRUPALIX9/logic-sprint.git
cd logic-sprint
make setup
make emulator    # optional: start Android emulator
make run
```

See all commands: `make help`

---

## Development

### Quality checks

```bash
make check
# or: make analyze && make test
```

CI runs the same steps on pushes and PRs to `production` and `develop` (see [.github/workflows/flutter_ci.yml](.github/workflows/flutter_ci.yml)).

### Git workflow

| Branch | Purpose |
|--------|---------|
| `production` | **Production** — store-ready releases |
| `develop` | **Integration** — day-to-day merges |
| `feature/*` | Short-lived work off `develop` |

- Normal PRs target **`develop`**
- Releases merge **`develop` → `production`**, then tag (e.g. `v1.0.0`)

Full guide: [docs/git_workflow.md](docs/git_workflow.md) · [CONTRIBUTING.md](CONTRIBUTING.md)

---

## Release builds

From **`production`** after a release merge:

```bash
make build-aab    # Android (.aab) for Google Play
make build-ios    # iOS IPA (requires Xcode)
```

Checklist: [docs/release_checklist.md](docs/release_checklist.md)

---

## Global Leaderboard (optional online)

- **Top 100** scores in Cloud Firestore (`leaderboardScores`)
- **Submit Score** on the Result screen only (not automatic)
- **Leaderboard screen** fetches at most 100 docs with `.get()` — no realtime listeners
- 10-minute local cache; **Refresh** has a 60-second cooldown
- Game/difficulty filters apply **locally** on cached data
- Max **5 submissions per device per day**
- App remains fully playable offline if Firestore is unavailable

Setup: [docs/firebase_setup.md](docs/firebase_setup.md) · Rules: [firestore.rules](firestore.rules)

**Credentials:** Admin SDK JSON lives in `credentials/` (gitignored). Client config is in `lib/firebase_options.dart` + platform Firebase files — see [credentials/README.md](credentials/README.md).

## Privacy & architecture

LogicSprint is **offline-first**:

- No login, ads, or analytics
- Local gameplay and high scores use `shared_preferences` only
- Optional leaderboard writes: display name, score, game, difficulty, app version, timestamp

Privacy text is bundled from `assets/brand/docs/privacy_policy.md` and shown in the in-app Privacy Policy screen.

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/git_workflow.md](docs/git_workflow.md) | `production` / `develop` branching |
| [docs/logic_sprint_epic_plan.md](docs/logic_sprint_epic_plan.md) | Product epic & tickets |
| [docs/brand_assets.md](docs/brand_assets.md) | Brand usage guide |
| [docs/release_checklist.md](docs/release_checklist.md) | Play Store & App Store prep |
| [assets/brand/docs/README.md](assets/brand/docs/README.md) | Brand kit file index |
| [assets/brand/docs/store_listing.md](assets/brand/docs/store_listing.md) | Store description draft |

---

## Dependencies

- `provider` — app settings state
- `shared_preferences` — high scores, leaderboard cache, preferences
- `firebase_core` + `cloud_firestore` — optional Global Top 100 leaderboard
- `audioplayers` — sound (optional)
- `flutter_animate` — light UI motion

Dev: `flutter_launcher_icons` — sync launcher icons from brand PNGs.

---

## License

Private project — not published to pub.dev (`publish_to: none`).
