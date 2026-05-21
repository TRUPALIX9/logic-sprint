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

Drop game tile PNGs into `games/<game_id>/` when available. Until then, the app uses `GameBrand` color accents + Material icons.

## Regenerate launcher icons

```bash
dart run flutter_launcher_icons
```
