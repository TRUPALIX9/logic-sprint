# LogicSprint: Software Lifecycle, Architecture, and Usage Manual

Welcome to the **LogicSprint: Brain Games** Software Lifecycle, Architecture, and Usage manual. This document covers the comprehensive details of the application structure, game loop mechanics, database cost-mitigation strategies, cybersecurity design, and branching/release operations for the **v0.0.1 Release**.

---

## 1. High-Level Architecture

LogicSprint is built on a modular, offline-first, state-managed Flutter architecture utilizing **Dart 3.x** and **Flutter 3.x**.

```text
+-------------------------------------------------------------+
|                        Presentation                         |
|   (Splash, Home, GameSelect, Difficulty, Gameplay Screens)  |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|               State Management & Controllers                |
|       (AppState [Provider], Game Specific Controllers)       |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                      Service Framework                      |
| (LocalStorage, Sound, AdService, Leaderboard, CacheService) |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                 Data & Infrastructure layers                 |
|            (Shared Preferences, Cloud Firestore)            |
+-------------------------------------------------------------+
```

### 1.1 State Management Architecture
- **Global App State (`AppState`)**: Wrapped in a root `ChangeNotifierProvider`, `AppState` manages user preferences (sound, vibration, dark/light theme, ad simulation mode) and provides high-score reading/writing proxies.
- **Screen Controllers**: Complex games (e.g., `RocketLaunchController`, `MemoryLaneController`) utilize independent, state-bound controller classes inheriting from `ChangeNotifier`. They encapsulate all math/physics coordinate logic, score aggregation, timers, and round state tracking, decoupling business logic from standard UI layouts.

---

## 2. Core Software Lifecycle & Game Loops

The application operates in a deterministic linear loop designed to provide rich feedback and fluid player journeys:

```text
[Splash Screen]
       | (Logo Animation, 1.5s delay)
       v
[Home Screen] <-----------------------+
       |                              |
       v                              |
[Game Selection]                      |
       |                              |
       v                              |
[Difficulty Selector]                 |
       |                              |
       v                              |
[Gameplay Loop (30s Timer)]           | (Back to Home / Play Again)
       |                              |
       v                              |
[Ad Interstitial Intercept]           |
       |                              |
       v                              |
[Result Screen] ----------------------+
  - Displays round statistics (Accuracy, Score, Best)
  - Interactive "Submit Score" trigger to Global Leaderboard
```

### 2.1 Mini-Game Loops
LogicSprint implements exactly two responsive mini-games optimized for high-performance rendering:

#### A. Rocket Launch (Space Survival Coordination)
- **Concept:** Asteroid-dodging space survival game.
- **Controls:** Supports both touch dragging (translating horizontal coordinates from 5% to 95% of screen width) and large 3D physical steering arrow buttons (`LEFT` and `RIGHT`).
- **Loop Logic:** Game generates asteroids at randomized positions spawning from `y = 0.0`. They accelerate downward towards the rocket at `y = 0.85`. Points are awarded for survival over time, with streak multipliers triggering for successive flawless seconds. Collisions instantly trigger clean sound triggers, reset the streak, and subtract a life/penalty depending on difficulty.

#### B. Memory Lane (Visual Spatial Sequencer)
- **Concept:** Grid block pattern sequencer (Simon style).
- **Difficulty Scaling:**
  - **Easy:** 3x3 layout (starting sequence: 3 blocks)
  - **Medium:** 4x4 layout (starting sequence: 4 blocks)
  - **Hard:** 5x5 layout (starting sequence: 5 blocks)
- **Loop Logic:**
  1. **Playback Stage:** Board locks touch input. Sequencer flashes blocks in random sequence with custom highlight colors. Playback uses spring animations (`flutter_animate`) with a tactile shimmer.
  2. **Input Stage:** Board unlocks touch input. Player repeats the sequence. Tapping correct blocks depresses the physical 3D tile and plays correct tone triggers. Tapping an incorrect block resets level progression. Correct sequence repetition advances level and increases block sequence length by 1.

---

## 3. Database Optimization & Free Tier Guarantees

Leaderboards leverage **Cloud Firestore** under the standard **Firebase Spark Free Plan** (50,000 daily reads, 20,000 daily writes). To protect against rate-limit exhaustion and eliminate billing risks, LogicSprint enforces four strategic optimization layers:

- **Layer A: Local-Only Filtering & Sorting**
  We avoid sending customized query filters to the backend. Instead, we query a flat list of at most the **Top 100 global scores** (`leaderboardScores` collection, ordered descending). Sorting or filtering by game ('Rocket Launch', 'Memory Lane') or difficulty ('Easy', 'Medium', 'Hard') is done **entirely in device RAM (locally)**. This yields exactly zero extra reads when the player changes filter dropdowns.
- **Layer B: 10-Minute Local Cache Window**
  Query results are serialized and saved inside SharedPreferences for 10 minutes. Opening or returning to the leaderboard screen within this window reads from memory instantly, executing **zero network requests** and **zero database reads**.
- **Layer C: Manual Refresh Cooldown**
  A manual refresh button executes real database queries only if the **60-second manual cooldown** has expired. Within this cooldown, the user is presented with a polite countdown tip.
- **Layer D: Daily Device Limit (5 Submissions)**
  Each physical device is limited to exactly **5 global leaderboard submissions per 24-hour cycle**, validated locally against SharedPreferences timestamps. Game loops and local high scores remain 100% active even after this limit is reached.

---

## 4. Cybersecurity & Integrity Protection

A formal analysis of LogicSprint's codebase confirms a highly secure, hardened architecture:

1. **No Hardcoded API Keys / Secrets:**
   Production configs, service account credentials, and platform keys are never committed to public repositories. Build environments read from `credentials/` (gitignored) or use GitHub Actions Secrets, automatically injecting configurations during compiles using `scripts/refresh_firebase_client_config.sh`.
2. **Input Sanitization & Injection Defense:**
   The `PlayerNameValidator` blocks standard database/NoSQL injection risks. Display names are strictly matched against a secure alphanumeric RegExp (`r'^[A-Za-z0-9 _\-]+$'`), limited to 20 characters, and trimmed of trailing whitespaces.
3. **Firestore Security Rules:**
   Our backend `firestore.rules` is configured strictly to enforce structural integrity. It prevents updates and deletes from client devices (`allow update, delete: if false`). Create payloads are schema-checked: they must strictly contain only valid fields, validate that `score` is a positive integer under `999,999`, verify that `playerName` conforms to size constraints, enforce server-side time matching (`createdAt == request.time`), and validate game and difficulty against an enum whitelist:
   ```javascript
   request.resource.data.gameType in ['rocketLaunch', 'memoryLane']
   request.resource.data.difficulty in ['easy', 'medium', 'hard']
   ```

---

## 5. Software Development & Release Operations (v0.0.1)

LogicSprint utilizes a rigid branch isolation and pipeline model to ensure build stability:

### 5.1 Git Branching Policy
- **`production`**: Production-ready, store-signed builds.
- **`develop`**: Daily development integration branch. All features target this branch.
- **`feature/*`**: Individual features or UI polishes branched from and merged into `develop`.

*For version 0.0.1, we are submitting our final verified build via a Release Pull Request from `develop` to `production`.*

### 5.2 Build & Verification Commands
Always run static analysis and tests locally before initiating a merge:

```bash
# Get dependencies
flutter pub get

# Run static analyzer
flutter analyze

# Execute comprehensive test suites
flutter test
```

### 5.3 Automated CI/CD (GitHub Actions)
Our build pipeline in `.github/workflows/release.yml` automates compiling production-grade deliverables:
1. **Trigger:** Every push to `production` spins up a macOS-latest runner.
2. **Configuration Recovery:** Securely restores `FIREBASE_SERVICE_ACCOUNT` from GitHub Secrets, executing Python/Bash builders to generate `google-services.json`, `GoogleService-Info.plist`, and `lib/firebase_options.dart`.
3. **Android Compilation:** Compiles signed Production Android App Bundles (`.aab`) ready for uploading to Google Play Console.
4. **iOS Compilation:** Compiles an unsigned/store-ready iOS `.ipa` bundle.
5. **Artifact Storage:** Bundled archives are uploaded and available to download directly from the Actions run dashboard!
