# LogicSprint Release Checklist (v0.0.1)

## Critical blockers (before store upload)

### Android release signing

- [ ] Create `android/upload-keystore.jks` and `android/key.properties` — see [android_release_signing.md](android_release_signing.md)
- [ ] Confirm `flutter build appbundle --release` uses the **release** signing config (not debug)
- [ ] Never commit `key.properties` or `*.jks`

### Firebase (optional Global Top 100)

Required only if the leaderboard should work in production:

- [ ] Add `android/app/google-services.json` (from Firebase Console or `./scripts/refresh_firebase_client_config.sh`)
- [ ] Add `ios/Runner/GoogleService-Info.plist` for iOS builds
- [ ] Replace `REPLACE_*` placeholders in `lib/firebase_options.dart` via refresh script (do **not** commit real API keys to a public repo)
- [ ] Deploy [firestore.rules](../firestore.rules) — see [firebase_setup.md](firebase_setup.md)

Without the above, the app still runs offline; leaderboard submit/fetch shows unavailable.

---

## Pre-release verification

- [x] `make check` (or `flutter analyze` + `flutter test`) — no errors
- [x] `make hooks-install` on dev machines (pre-push runs same checks as CI)
- [x] App name: **LogicSprint** (display: **LogicSprint: Brain Games**)
- [x] Version in `pubspec.yaml` matches `0.0.1+1` (via `package_info_plus`)
- [x] **INTERNET** permission present in `AndroidManifest.xml` (required for optional Firestore leaderboard + Google Mobile Ads)
- [x] Dynamic Ads: Simulated overlay, Real AdMob, and Disabled modes switch successfully in Settings
- [x] Privacy policy screen present
- [x] High scores and settings persist locally
- [x] Light and dark mode work without text contrast issues
- [x] Exactly two v1 games playable end-to-end (Rocket Launch, Memory Lane)
- [x] Android splash uses brand Midnight Purple (`#12002F`) + launcher icon
- [x] Custom 3D tactile buttons (`GameTactileButton`) press down dynamically with haptic vibration responses

## Build commands

```bash
# After android/key.properties exists:
flutter build appbundle --release
flutter build ipa --release
```

## Google Play Store

**Short description (80 chars max):**
Fast brain games: asteroid survival and memory grids — offline or Top 100.

**Full description:**
LogicSprint: Brain Games is a free app with quick 30-second mini-games that train speed, logic, and focus. Play Rocket Launch or Memory Lane at Easy, Medium, or Hard difficulty. Track local high scores, toggle sound and theme, customize ad simulation mode, and optionally compete on the Global Top 100 leaderboard.

**Category:** Puzzle / Educational  
**Keywords:** brain games, space coordination, memory grid, logic, offline, puzzle, quick thinking
**Data safety:** Local scores on device; optional leaderboard writes (display name, score, game, difficulty) if user submits  
**Content rating:** Everyone / 3+

**Screenshots:** Home, game select, each game, result, leaderboard, high scores, settings (phone + optional tablet)

## Apple App Store

**Subtitle:** Fast logic & memory challenges
**Category:** Games → Puzzle or Education  
**Privacy nutrition:** Data not collected (except optional leaderboard submission)  
**Age rating:** 4+

## Store listing assets

- [ ] App icon from brand kit (1024×1024)
- [ ] 6–8 screenshots
- [ ] Privacy policy URL or in-app policy reference
- [ ] Support contact email (optional)

## QA smoke test

1. Cold launch → branded splash → home
2. Play each game on each difficulty
3. Verify 30s timer, scoring, streak bonus
4. Result screen stats match gameplay
5. High score updates and persists after restart
6. Leaderboard: loads or shows graceful offline message
7. Settings: sound, vibration, ads mode, reset scores
8. About shows version `0.0.1+1` from `pubspec.yaml`; Privacy Policy screen
