# LogicSprint: Brain Games

LogicSprint is an offline Flutter mobile game app for Android and iOS. Version 1 includes Quick Math, Number Sequence, and True or False, with local-only high scores and settings stored through `shared_preferences`.

## Docs

- [Git workflow (main + develop)](docs/git_workflow.md)
- [Epic plan](docs/logic_sprint_epic_plan.md)
- [Brand assets](docs/brand_assets.md)
- [Release checklist](docs/release_checklist.md)

## Git branches

- `main` — production / store releases
- `develop` — integration (default for PRs)

## Brand

Official kit under `assets/brand/` — see `assets/brand/docs/README.md`. App code uses `BrandAssets`, `BrandPalette`, and `BrandLogo`. Launcher icons: `dart run flutter_launcher_icons`.

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
flutter analyze
flutter test
```

## Release Builds

```bash
flutter build appbundle --release
flutter build ipa --release
```

## Store Readiness Notes

- No backend
- No login
- No Firebase
- No ads
- No analytics
- No internet dependency
- Local-only storage for scores, sound, vibration, and theme mode

## Future Roadmap

- Memory Pattern
- Color Confusion
- Tap in Order
- Odd One Out
- Word Scramble
