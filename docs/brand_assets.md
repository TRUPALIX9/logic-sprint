# LogicSprint Brand Asset Guide

## Master brand (LogicSprint)

Derived from `assets/brand/tokens/brand_tokens.json` (original concept crops).

| Token            | Hex       | Usage                    |
| ---------------- | --------- | ------------------------ |
| Midnight Purple  | `#12002F` | Dark backgrounds, splash |
| Deep Blue        | `#004F9F` | Headers, depth           |
| Electric Blue    | `#23BEEF` | Primary actions          |
| Sprint Orange    | `#FC8620` | CTAs, accents            |
| Soft Ice         | `#D8E5EC` | Light surfaces           |
| Ink              | `#130A33` | Text on light surfaces   |

Code: `lib/core/brand/brand_palette.dart`, `lib/core/brand/brand_assets.dart`, `lib/widgets/brand_logo.dart`.

## Per-game brand sets

Each mini-game has its own accent layer on the master palette:

### Rocket Launch

- **Accent:** Deep Blue + Electric Blue gradient
- **Motif:** Spaceship / asteroids avoidance / survival
- **Code:** `GameBrand.rocketLaunch`
- **Listing art:** `BrandAssets.gameListingArt(GameType.rocketLaunch)` -> `logoMark`

### Memory Lane

- **Accent:** Sprint Orange + Deep Purple gradient
- **Motif:** Bright flashing sequential blocks / grid cells
- **Code:** `GameBrand.memoryLane`
- **Listing art:** `BrandAssets.gameListingArt(GameType.memoryLane)` -> `appIcon512`

## Differentiation rules

1. **Shared:** Logo mark, navy surfaces, typography, 30s round UX, GameTactileButton elements.
2. **Game-specific:** Card accent color, difficulty strip gradient, game select icon tint.
3. **Do not mix:** Use `GameBrand.forGame()` — never hard-code per-game colors in shared widgets.

## Export checklist (design)

- [ ] App icon 1024×1024 (no text)
- [ ] Feature graphic 1024×500
- [ ] Screenshots per game (light + dark)
- [ ] Rocket Launch tile PNG → `assets/brand/games/rocket_launch/tile.png`
- [ ] Memory Lane tile PNG → `assets/brand/games/memory_lane/tile.png`
