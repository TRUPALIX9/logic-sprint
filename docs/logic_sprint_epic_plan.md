# LogicSprint Product and Epic Plan (Updated for v0.0.1 Release)

## Document Purpose

This document is the planning artifact for **LogicSprint: Brain Games**. It defines the implementation epic, acceptance criteria, target architecture, execution order, delivery standards, QA coverage, and mobile release checklist for the Flutter app.

## Current Baseline

- Flutter app scaffold with full `lib/` architecture is implemented.
- Exactly two polished mini-games: **Rocket Launch** and **Memory Lane**.
- Shared timed game engine, local storage, settings, themes, and brand tokens are in place.
- Dual-mode `AdService` and cached Firebase leaderboard system are fully implemented.
- See `docs/release_checklist.md` and `docs/brand_assets.md` for store and design handoff.

## Epic Title

**Build LogicSprint: Brain Games Flutter App**

## Epic Description

Build a free offline mobile brain game app for Android and iOS using Flutter and Dart. LogicSprint ships with two highly polished, responsive mini-games: **Rocket Launch** (space asteroid survival with coordinate dragging or 3D steering controls) and **Memory Lane** (sequential Simon-style grid sequencer on scaled 3x3, 4x4, and 5x5 boards). The app works fully offline by default, requiring no login. It stores scores and user settings locally using `shared_preferences`, and features an optional Cloud Firestore Global Top 100 Leaderboard shielded by multi-layered cost-mitigation caching and manual refresh cooldowns to eliminate database billing risks.

The implementation prioritizes a clean modular architecture, physical 3D spring button widgets (`GameTactileButton`), customizable light and dark themes, rich fluid animations, and robust local persistence.

## Product Goals

- Deliver a complete offline-first, high-quality Flutter app for Android and iOS.
- Make gameplay fast, clear, and rewarding in 30-second rounds.
- Keep the codebase modular so future games can plug into shared systems.
- Persist high scores and settings locally without introducing backend complexity.
- Provide a store-ready, automated CI/CD release pipeline using GitHub Actions.

## Version 0.0.1 Scope

- Rocket Launch (Asteroid avoidance space survival game)
- Memory Lane (Simon-style sequential pattern sequencer)
- Splash screen with brand entrance animation
- Home screen with direct game access, interactive ad banner, and global navigation
- Game selection screen
- Difficulty selection screen (Easy, Medium, Hard)
- Result screen showcasing detailed round statistics (accuracy, score, streak) and manual "Submit Score" trigger
- Global Leaderboard screen with local sorting/filtering, 10-minute cache window, and 60-second cooldown
- High scores screen
- Settings screen supporting sound, vibration, dynamic ad toggling, and data resets
- About & Privacy Policy screens
- Custom GameTactileButton with physical depression animations and haptic vibration feedback
- Dual-Mode AdService supporting Simulated and Real AdMob Ads

## Out of Scope for Version 0.0.1

- Account creation or login
- Backend cloud storage for game states (everything is local-first)
- Unbounded analytics/telemetry trackers
- Paid features or subscriptions (fully free to play)

## Acceptance Criteria

1. The app launches into a branded LogicSprint experience with custom entrance animations.
2. Users can navigate fluidly between splash, home, game select, difficulty, game, result, leaderboard, high scores, settings, about, and privacy policy screens.
3. Users can select any of the two mini-games and choose `easy`, `medium`, or `hard`.
4. Each game round lasts exactly 30 seconds, controlled by a shared game engine.
5. Correct answers/survival triggers add 10 points.
6. A streak of 5 correct actions/survival intervals awards a 20-point bonus.
7. Each game tracks score, correct answers, wrong answers, streak, and accuracy.
8. When the timer ends, the app navigates safely to the result screen with accurate statistics.
9. High scores are saved locally per game and per difficulty with `shared_preferences`.
10. Settings for sound, vibration, and theme mode persist across app restarts.
11. Custom 3D buttons (`GameTactileButton`) simulate spring depress physics and vibrate if enabled.
12. AdService handles banner and interstitial loading and switches flawlessly between Simulated, Real AdMob, and Disabled modes.
13. Global Leaderboard caches Firestore documents for 10 minutes and enforces a 60-second cooldown on forced refreshes to guarantee free tier billing immunity.
14. `flutter analyze` passes without warnings.
15. `flutter test` passes all widget and controller test suites.
16. Android/iOS release builds compile cleanly.

## App Architecture Summary

### Architectural Style

Use a **clean modular Flutter architecture** with clear separation between:

- `core`: constants, theme, utility helpers, shared enums, and reusable engine pieces
- `models`: immutable app and game data structures
- `services`: persistence, ads, sound, and backend database integrations
- `screens`: presentation layers organized by feature
- `widgets`: reusable UI building blocks and responsive elements
- `controllers`: state management and core mini-game coordinate/pattern engines

---

## Technical Details: Implemented Games

### 1. Rocket Launch (Space Survival Coordination)
- **Concept:** Asteroid dodging survival coordination.
- **Controls:** Direct touch dragging + large physical 3D steering arrows (`LEFT` and `RIGHT`).
- **Engine Loop:** Generates asteroid elements at random x-coordinates from `y = 0.0` accelerating downward to the ship at `y = 0.85`. High accuracy and flawless seconds reward consecutive streaks. Collisions trigger sound/vibration cues and reset active streak multipliers.

### 2. Memory Lane (Simon Sequencer)
- **Concept:** Color flash grid pattern sequencer.
- **Scaling:** Easy is 3x3 layout (3 blocks sequence); Medium is 4x4 layout (4 blocks sequence); Hard is 5x5 layout (5 blocks sequence).
- **Engine Loop:** Highlight block pathways using spring motion transforms. Board touch locks are applied dynamically during playback. Correct taps depress the physical tile and advance progression; incorrect taps instantly reset the streak. Sequence length increments by 1 for each round solved.
