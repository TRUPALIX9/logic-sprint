# LogicSprint Brand Assets

Production kit (original artwork crops). **Use the paths in `lib/core/brand/brand_assets.dart` in app code.**

## Best file per use case

| Use case | File |
|----------|------|
| **Launcher / app icon** | `icons/app_icon_1024.png` |
| **Android adaptive icon** | `icons/android/adaptive_icon_foreground.png` + `adaptive_icon_background.png` |
| **Play Store icon** | `store/google_play/play_store_icon_512.png` |
| **Play feature graphic** | `store/google_play/feature_graphic_1024x500.png` |
| **In-app mark (compact)** | `logos/png/logo_mark_original_transparent.png` |
| **Hero / splash (dark bg)** | `logos/png/horizontal_lockup_white.png` |
| **Light surfaces** | `logos/png/horizontal_lockup_dark.png` |
| **Colors in code** | `tokens/brand_tokens.json` → `BrandPalette` |
| **Privacy copy** | `docs/privacy_policy.md` |
| **Store copy** | `docs/store_listing.md` |

## Do not use in production UI

- `logicsprint/brand_kit_master.png` — full mood board only
- `logos/png/original_*_crop.png` — reference crops; prefer `logo_mark_original_transparent.png`

## Per-game assets

| Game ID | Folder | Listing art (until `tile.png` exists) |
|---------|--------|----------------------------------------|
| Quick Math | `games/quick_math/` | `logo_mark_original_transparent.png` |
| Color Sequence | `games/color_sequence/` | `app_icon_512.png` |
| True or False | `games/true_false/` | `horizontal_lockup_transparent.png` |

Drop **`tile.png`** into each folder for dedicated game-select artwork. Until then, the app uses the listing art above via `BrandAssets.gameListingArt()` and `GameBrandArt`.

## Regenerate launcher icons

```bash
dart run flutter_launcher_icons
```
