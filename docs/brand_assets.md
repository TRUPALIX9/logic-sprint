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

### Quick Math

- **Accent:** Electric Blue + Sky Blue gradient
- **Motif:** Calculator / arithmetic
- **Code:** `GameBrand.quickMath`

### Color Sequence

- **Accent:** Sprint Orange + Brain Cyan gradient
- **Motif:** Color pads, Simon-style sequence
- **Code:** `GameBrand.colorSequence`
- **Listing art:** `BrandAssets.gameListingArt(GameType.colorSequence)` → app icon until `games/color_sequence/tile.png`

### True or False

- **Accent:** Success green + electric blue
- **Motif:** Fact check, rapid decisions
- **Code:** `GameBrand.trueFalse`

### Coming soon

- **Emoji Match, Pattern Lock, Memory Pattern** — see `docs/new_memory_games_plan.md`

## Differentiation rules

1. **Shared:** Logo mark, navy surfaces, typography, 30s round UX.
2. **Game-specific:** Card accent color, difficulty strip gradient, game select icon tint.
3. **Do not mix:** Use `GameBrand.forGame()` — never hard-code per-game colors in shared widgets.

## Export checklist (design)

- [ ] App icon 1024×1024 (no text)
- [ ] Feature graphic 1024×500
- [ ] Screenshots per game (light + dark)
- [ ] Quick Math tile PNG → `assets/brand/games/quick_math/tile.png`
- [ ] Color Sequence tile PNG → `assets/brand/games/color_sequence/tile.png`
- [ ] True or False tile PNG → `assets/brand/games/true_false/tile.png`
