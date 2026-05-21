# Firebase setup (Global Leaderboard only)

Project: **logic-sprint**

LogicSprint uses **Cloud Firestore** only for the optional Global Top 100 leaderboard. Gameplay and local high scores stay on-device.

## Two different credential types

| File | Purpose | In Git? | In Flutter app? |
|------|---------|---------|-----------------|
| `credentials/logic-sprint-firebase.json` | **Admin SDK** — deploy rules, admin tools | **No** (gitignored) | **Never** |
| `android/app/google-services.json` | Android **client** config | Yes | Yes |
| `ios/Runner/GoogleService-Info.plist` | iOS **client** config | Yes | Yes |
| `lib/firebase_options.dart` | Dart **client** config | Yes | Yes |

Your Admin SDK key in `credentials/` is already wired for CLI use only. The app connects with the client files above.

## 1. Deploy Firestore security rules

From the repo root (Admin SDK JSON in `credentials/`):

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials/logic-sprint-firebase.json"
firebase deploy --only firestore:rules --project logic-sprint
```

Optional helper: `scripts/deploy_firestore_rules.sh` runs the same command.

Rules file: [firestore.rules](../firestore.rules)

## 2. Enable Firestore

In [Firebase Console](https://console.firebase.google.com/project/logic-sprint/firestore) → create database (production mode) if not already created.

## 3. Run the app

```bash
flutter pub get
flutter run
```

`AppFirebaseService.initialize()` runs at startup. If client config is present, the Global Leaderboard can read/write Firestore. Offline play still works if Firebase is unavailable.

## 4. Refresh client config (optional)

If you add new apps or rotate keys:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials/logic-sprint-firebase.json"
export PATH="$PATH:$HOME/.pub-cache/bin"
flutterfire configure --project=logic-sprint --platforms=android,ios
```

## Firestore collection

- Collection: `leaderboardScores`
- Reads: Top 100 by `score` descending (leaderboard screen only, `.get()`)
- Writes: User taps **Submit Score** on Result screen (max 5/day per device)

## Quota tips

- No realtime listeners
- No reads on app startup or Home
- Filters are local on cached Top 100
- 10-minute cache + 60-second refresh cooldown

## Security reminder

- Rotate the Admin SDK key if it was ever committed or shared
- Never paste `credentials/*.json` into the app source or public repos
