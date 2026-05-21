# LogicSprint Release Checklist

## Pre-release verification

- [ ] `flutter analyze` — no errors
- [ ] `flutter test` — all pass
- [ ] App name: **LogicSprint** (display: **LogicSprint: Brain Games**)
- [ ] Version **1.0.0+1** in `pubspec.yaml`
- [ ] No `INTERNET` permission in Android manifest
- [ ] No Firebase, analytics, ads, or login code
- [ ] Privacy policy screen present
- [ ] High scores and settings persist locally
- [ ] Light and dark mode work
- [ ] All three v1 games playable end-to-end

## Build commands

```bash
flutter build appbundle --release
flutter build ipa --release
```

## Google Play Store

**Short description (80 chars max):**
Fast offline brain games: math, sequences, and true/false challenges.

**Full description:**
LogicSprint: Brain Games is a free offline app with quick 30-second mini-games that train speed, logic, and focus. Play Quick Math, Number Sequence, and True or False at Easy, Medium, or Hard difficulty. Track local high scores, toggle sound and theme, and play anywhere with no account required.

**Category:** Puzzle / Educational  
**Keywords:** brain games, math, logic, offline, puzzle, quick thinking  
**Data safety:** No data collected; all storage on device  
**Content rating:** Everyone / 3+

**Screenshots:** Home, game select, each game, result, high scores, settings (phone + optional tablet)

## Apple App Store

**Subtitle:** Fast logic & math challenges  
**Category:** Games → Puzzle or Education  
**Privacy nutrition:** Data not collected  
**Age rating:** 4+

## Store listing assets

- [ ] App icon from brand kit (1024×1024)
- [ ] 6–8 screenshots
- [ ] Privacy policy URL or in-app policy reference
- [ ] Support contact email (optional)

## QA smoke test

1. Cold launch → splash → home
2. Play each game on each difficulty
3. Verify 30s timer, scoring, streak bonus
4. Result screen stats match gameplay
5. High score updates and persists after restart
6. Settings: sound, vibration, theme, reset scores
7. About and Privacy Policy screens
