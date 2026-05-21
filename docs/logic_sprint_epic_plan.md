# LogicSprint Product and Epic Plan

## Document Purpose

This document is the Agent 1 planning artifact for **LogicSprint: Brain Games**. It defines the implementation epic, acceptance criteria, target architecture, execution order, delivery standards, QA coverage, and mobile release checklist for the Flutter app.

## Current Baseline

- Flutter app scaffold with full `lib/` architecture is implemented.
- Version 1 games: Quick Math, Number Sequence, True or False.
- Shared timed game engine, local storage, settings, themes, and brand tokens are in place.
- See `docs/release_checklist.md` and `docs/brand_assets.md` for store and design handoff.

## Epic Title

**Build LogicSprint: Brain Games Flutter App**

## Epic Description

Build a free offline mobile brain game app for Android and iOS using Flutter and Dart. Version 1 of LogicSprint will ship with three mini-games: **Quick Math**, **Number Sequence**, and **True or False**. The app must work fully offline, require no login, use no backend services, include no Firebase, analytics, ads, or internet dependency, and store scores and user settings locally with `shared_preferences`.

The app should feel polished and easy to extend so future mini-games can be added without rewriting the app shell or core game logic. The implementation should prioritize clean modular architecture, reusable game engine logic, light and dark themes, simple animations, and reliable local persistence.

## Product Goals

- Deliver a complete offline-first Flutter app for Android and iOS.
- Make gameplay fast, clear, and rewarding in 30-second rounds.
- Keep the codebase modular so future games can plug into shared systems.
- Persist high scores and settings locally without introducing backend complexity.
- Provide a store-ready baseline for Android and iOS release preparation.

## Version 1 Scope

- Quick Math
- Number Sequence
- True or False
- Splash screen
- Home screen
- Game selection screen
- Difficulty selection screen
- Result screen
- High scores screen
- Settings screen
- About screen
- Privacy policy screen
- Light theme and dark theme
- Local settings and high score persistence

## Out of Scope for Version 1

- Account creation or login
- Cloud sync
- Multiplayer
- Ads or rewarded videos
- Analytics or telemetry
- Internet-based content
- Remote configuration
- Purchases or subscriptions
- Memory Pattern, Color Confusion, Tap in Order, Odd One Out, Word Scramble

## Acceptance Criteria

1. The app launches into a branded LogicSprint experience instead of the default Flutter counter app.
2. Users can navigate between splash, home, game select, difficulty, game, result, high scores, settings, about, and privacy policy screens.
3. Users can select any Version 1 mini-game and choose `easy`, `medium`, or `hard`.
4. Each game round lasts exactly 30 seconds.
5. Correct answers add 10 points.
6. Wrong answers add 0 points.
7. A streak of 5 correct answers awards a 20-point bonus.
8. Each game tracks score, correct answers, wrong answers, streak, and accuracy.
9. When the timer ends, the app navigates to the result screen with accurate final stats.
10. High scores are saved locally per game and per difficulty with `shared_preferences`.
11. Settings for sound, vibration, and theme mode persist across app restarts.
12. The app supports both light mode and dark mode.
13. The app works offline and contains no backend calls.
14. The app contains no login flow, no Firebase, no analytics, and no ads.
15. `flutter analyze` passes.
16. `flutter test` passes with game generation coverage.
17. Android release build succeeds.
18. iOS release build succeeds.

## App Architecture Summary

### Architectural Style

Use a **clean modular Flutter architecture** with clear separation between:

- `core`: constants, theme, utility helpers, shared enums, and reusable engine pieces
- `models`: immutable app and game data structures
- `services`: persistence and future device capability abstractions
- `screens`: presentation layers organized by feature
- `widgets`: reusable UI building blocks
- `controllers`: game-specific state and question generation logic

### State Management

- Use `provider` for lightweight dependency injection and state updates.
- Keep app-wide services available near the root of the app.
- Keep game-specific controllers scoped to their respective game screens.

### Navigation

- Use named routes defined in a single route constants file.
- Pass route arguments through typed argument classes or structured maps where needed.
- Keep navigation flow predictable:
  `Splash -> Home -> Game Select -> Difficulty -> Game -> Result`

### Persistence

- Use `shared_preferences` only.
- Store:
  - high scores by `GameType` and `DifficultyLevel`
  - `isSoundEnabled`
  - `isVibrationEnabled`
  - `themeMode`

### Shared Game Engine

Create reusable game session logic so all mini-games share:

- 30-second countdown timer
- score calculation
- streak tracking
- 5-correct bonus handling
- accuracy calculation
- result payload generation
- local high score save/update flow

This shared engine should be generic enough to support future games without copying timer or scoring logic into each screen.

### Extensibility Principles

- Represent games with enums and metadata models.
- Keep question generation isolated in controller or helper layers.
- Make result handling independent of any specific game.
- Ensure future mini-games can reuse the same shell, persistence, scoring, and routing patterns.

## Target Folder Structure

```text
lib/
  main.dart
  app.dart

  core/
    constants/
      app_colors.dart
      app_strings.dart
      app_routes.dart
    theme/
      app_theme.dart
    utils/
      random_utils.dart
      score_utils.dart

  models/
    game_model.dart
    question_model.dart
    score_model.dart

  services/
    local_storage_service.dart
    sound_service.dart

  screens/
    splash/
      splash_screen.dart
    home/
      home_screen.dart
    game_select/
      game_select_screen.dart
    difficulty/
      difficulty_screen.dart
    games/
      quick_math/
        quick_math_screen.dart
        quick_math_controller.dart
      number_sequence/
        number_sequence_screen.dart
        number_sequence_controller.dart
      true_false/
        true_false_screen.dart
        true_false_controller.dart
    result/
      result_screen.dart
    high_scores/
      high_scores_screen.dart
    settings/
      settings_screen.dart
    about/
      about_screen.dart
      privacy_policy_screen.dart

  widgets/
    primary_button.dart
    game_card.dart
    answer_button.dart
    timer_bar.dart
    score_header.dart
    custom_app_bar.dart
    empty_state.dart

test/
  unit/
    quick_math_generation_test.dart
    number_sequence_generation_test.dart
    true_false_generation_test.dart
    score_utils_test.dart
    local_storage_service_test.dart
  widget/
    app_smoke_test.dart
```

## Recommended Core Domain Types

- `enum GameType { quickMath, numberSequence, trueFalse }`
- `enum DifficultyLevel { easy, medium, hard }`
- `GameModel`
- `QuestionModel`
- `ScoreModel`
- `GameResultModel` or equivalent result payload

## Child Tickets in Execution Order

### Ticket 1: Replace Flutter Starter With LogicSprint App Shell

**Goal**
Replace the default counter app with a clean app entry point, dependency wiring, and named-route shell.

**Deliverables**

- `main.dart` initializes app services
- `app.dart` hosts `MaterialApp`
- named route map
- placeholder screen registration
- app title and branding baseline

**Definition of Done**

- No default counter sample code remains
- App launches into LogicSprint shell
- Named routes compile and navigate correctly
- App branding uses LogicSprint naming consistently

### Ticket 2: Create Core Constants, Theme, and Shared UI Foundation

**Goal**
Establish design tokens, light/dark themes, reusable widgets, and shared app strings.

**Deliverables**

- app colors
- app strings
- route constants
- light and dark theme definitions
- shared widgets such as buttons, cards, headers, timer bar, empty state, and app bar

**Definition of Done**

- Light and dark themes both render correctly
- Shared widgets are reusable and not tied to a single screen
- Typography and spacing are consistent across placeholder screens

### Ticket 3: Implement Models and Local Storage Service

**Goal**
Create app data models and local persistence abstractions.

**Deliverables**

- game, question, score, and result models
- `LocalStorageService`
- storage keys for scores and settings
- load/save/reset methods

**Definition of Done**

- Storage keys match product requirements
- High scores can be saved and read by game and difficulty
- Settings can be saved and read reliably
- Storage access is encapsulated behind a service API

### Ticket 4: Implement Shared Game Engine

**Goal**
Build reusable session logic for timer, scoring, streaks, accuracy, and result generation.

**Deliverables**

- reusable game session state/controller base
- 30-second timer logic
- +10 scoring logic
- +20 streak bonus at 5-correct intervals
- result calculation and payload generation
- high score save/update integration

**Definition of Done**

- Game screens can reuse shared engine behavior without duplicating timer and score code
- Timer ends the round and triggers result navigation consistently
- Accuracy, streak, and score values are correct under unit tests

### Ticket 5: Implement Quick Math Game

**Goal**
Ship Quick Math across all three difficulties.

**Deliverables**

- question generation by difficulty
- whole-number division handling in hard mode
- believable multiple-choice distractors
- screen using shared timer and score components
- feedback and next-question flow
- unit tests for question generation

**Definition of Done**

- Easy, medium, and hard rules match specification
- No duplicate answer options appear
- Hard division questions always resolve to whole numbers
- Game runs for 30 seconds and exits to result screen correctly
- Tests cover question generation logic

### Ticket 6: Implement Number Sequence Game

**Goal**
Ship Number Sequence across all three difficulties.

**Deliverables**

- addition, subtraction, multiplication, squares, and mixed sequence generation
- shuffled answer options with no duplicates
- screen using shared timer and score components
- unit tests for sequence generation

**Definition of Done**

- Difficulty tiers match specification
- Sequences are readable and unambiguous
- Options are unique and include the correct next value
- Game integrates with shared engine and result flow
- Tests cover generation logic

### Ticket 7: Implement True or False Game

**Goal**
Ship True or False across all three difficulties.

**Deliverables**

- statement generation for math, shape facts, and number facts
- true/false answer flow
- immediate feedback
- screen using shared timer and score components
- unit tests for statement generation

**Definition of Done**

- Statements are appropriate to each difficulty
- True and false cases are both generated
- Game integrates with shared engine and result flow
- Tests cover generation logic

### Ticket 8: Implement Result and High Scores Screens

**Goal**
Provide clear end-of-round feedback and persisted score visibility.

**Deliverables**

- result screen with score, best score, correct, wrong, and accuracy
- play again flow
- back to home flow
- high scores screen grouped by game and difficulty

**Definition of Done**

- Result values match actual gameplay session data
- Best score reflects persisted local storage
- High scores screen handles empty and populated states cleanly

### Ticket 9: Implement Settings, About, and Privacy Policy Screens

**Goal**
Add persistent app preferences and static informational screens.

**Deliverables**

- sound toggle
- vibration toggle
- theme mode toggle
- reset high scores action
- about screen
- privacy policy screen with required text

**Definition of Done**

- All settings persist after app restart
- Reset high scores clears all stored score values safely
- Privacy policy text exactly reflects offline-only data handling

### Ticket 10: UI/UX Polish and Animation Pass

**Goal**
Upgrade placeholders into a cohesive, polished game UI.

**Deliverables**

- branded splash screen
- polished home, game select, difficulty, gameplay, result, high scores, settings, about, and privacy screens
- responsive layouts
- `flutter_animate` transitions
- disabled coming-soon cards for future games

**Definition of Done**

- UI is visually consistent in both light and dark mode
- No overflow errors appear on small phones
- Animations improve clarity without harming responsiveness
- Coming-soon cards are clearly non-interactive

### Ticket 11: QA, Test Coverage, and Cleanup

**Goal**
Stabilize the app and remove implementation leftovers.

**Deliverables**

- `flutter analyze`
- `flutter test`
- bug fixes
- dead-code cleanup
- verification of offline-only behavior

**Definition of Done**

- Analyzer passes with no blocking issues
- Tests pass
- No debug placeholder text remains
- No unused routes or orphaned files remain

### Ticket 12: Release Preparation for Android and iOS

**Goal**
Prepare the app for store submission.

**Deliverables**

- app version set to `1.0.0`
- final app name and display title confirmed
- privacy/data handling review
- build commands documented
- release checklist completed

**Definition of Done**

- Android release build succeeds
- iOS release build succeeds
- Store metadata draft exists
- No prohibited backend/login/analytics/ad dependencies are present

## Cross-Ticket Engineering Standards

- Flutter and Dart only
- No backend integration
- No login flow
- No Firebase
- No analytics SDKs
- No ad SDKs
- No internet dependency
- Shared logic over duplicated per-screen logic
- Reusable widgets over copy-pasted UI
- Modular, readable file sizes
- Comments only where they clarify non-obvious logic

## Testing Checklist

### Functional Checks

- App launches into LogicSprint branding
- Splash screen transitions correctly
- Home screen navigation works
- Game selection navigation works
- Difficulty selection navigation works
- Quick Math works on easy
- Quick Math works on medium
- Quick Math works on hard
- Number Sequence works on easy
- Number Sequence works on medium
- Number Sequence works on hard
- True or False works on easy
- True or False works on medium
- True or False works on hard
- Timer always ends the round at 30 seconds
- Correct answers add 10 points
- Wrong answers do not add points
- 5-correct streak grants 20 bonus points
- Result screen displays correct score data
- Play Again restarts the same game flow correctly
- Back to Home returns safely from result screen

### Persistence Checks

- Quick Math high scores save for all three difficulties
- Number Sequence high scores save for all three difficulties
- True or False high scores save for all three difficulties
- Sound setting persists after restart
- Vibration setting persists after restart
- Theme mode persists after restart
- Reset high scores clears stored results and updates UI

### Quality Checks

- `flutter analyze` passes
- `flutter test` passes
- No broken routes remain
- No null-state crashes occur
- No duplicate answer options appear where prohibited
- No integer or division edge cases break question generation
- No overflow errors on small phones
- No obviously unreadable contrast in dark mode
- Animations remain smooth on lower-end devices
- No default Flutter demo text remains

### Compliance Checks

- No login screen exists
- No backend or API client exists
- No Firebase package exists
- No analytics package exists
- No ad package exists
- No internet permission is added intentionally
- App is fully usable offline

## Android Release Checklist

- Confirm package identity is final
- Confirm app name is **LogicSprint**
- Confirm display title can be **LogicSprint: Brain Games**
- Confirm version is `1.0.0`
- Confirm release signing configuration is prepared
- Confirm app icon assets are replaced from placeholder art
- Confirm splash experience is branded
- Confirm privacy policy screen exists in-app
- Confirm no internet permission is included unless explicitly justified later
- Run `flutter analyze`
- Run `flutter test`
- Run `flutter build appbundle --release`
- Validate generated `.aab`
- Smoke test release build on Android device or emulator
- Capture store screenshots
- Draft Google Play listing copy
- Complete Data Safety answers stating local-only behavior and no data collection

## iOS Release Checklist

- Confirm bundle identifier is final
- Confirm app display name is correct
- Confirm version is `1.0.0`
- Confirm launch and splash experience is branded
- Confirm app icons are replaced from placeholder art
- Confirm privacy policy screen exists in-app
- Run `flutter analyze`
- Run `flutter test`
- Run `flutter build ipa --release`
- Verify signing and provisioning configuration
- Smoke test on iPhone simulator and at least one physical device if available
- Capture App Store screenshots for required device classes
- Draft App Store listing copy
- Complete App Privacy answers stating no collected data and local-only storage

## Suggested Milestones

### Milestone 1: App Foundation

- Tickets 1 to 3

### Milestone 2: Shared Gameplay Systems

- Ticket 4

### Milestone 3: Version 1 Games

- Tickets 5 to 7

### Milestone 4: Shell Completion

- Tickets 8 to 9

### Milestone 5: Polish and Launch Readiness

- Tickets 10 to 12

## Delivery Risks and Mitigations

### Risk: Duplicated game logic across screens

**Mitigation**
Build the shared game engine before implementing individual games.

### Risk: Difficulty tuning becomes inconsistent

**Mitigation**
Represent difficulty behavior in centralized generation rules and cover with tests.

### Risk: High score persistence bugs

**Mitigation**
Abstract all reads and writes through `LocalStorageService` and add service-level tests.

### Risk: UI polish causes regressions late in the cycle

**Mitigation**
Complete functional flows first, then do a focused polish pass with smoke testing after UI changes.

### Risk: Small-screen layout overflows

**Mitigation**
Design gameplay screens with flexible layouts and validate on compact phone dimensions during QA.

## Recommended Execution Order

1. Product and epic planning
2. Flutter boilerplate and app shell
3. Shared game engine
4. Quick Math
5. Number Sequence
6. True or False
7. Result and high scores
8. Settings, about, and privacy
9. UI/UX polish
10. QA and release preparation

## Handoff Notes for Implementation Agents

- Start from the current Flutter starter scaffold, not an existing custom architecture.
- Prioritize replacing the demo app shell first so later work lands on the correct structure.
- Keep the route and model naming aligned with this document to reduce churn between tickets.
- Avoid introducing dependencies beyond `shared_preferences`, `provider`, `audioplayers`, and `flutter_animate` unless a new requirement is approved.
