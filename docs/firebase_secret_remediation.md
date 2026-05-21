# Firebase API key leak — remediation

GitHub secret scanning flagged Google API keys in `lib/firebase_options.dart` on branch `feature/firebase-leaderboard-and-color-sequence`.

**Those keys were exposed in a public repo. Treat them as compromised and rotate them.**

---

## What leaked (rotate these)

| Platform | Former location | Action |
|----------|-----------------|--------|
| Android | `lib/firebase_options.dart` line ~32 | **Rotate** in Google Cloud Console |
| iOS | `lib/firebase_options.dart` line ~40 | **Rotate** in Google Cloud Console |
| Android | `android/app/google-services.json` | Regenerate after rotation |
| iOS | `ios/Runner/GoogleService-Info.plist` | Regenerate after rotation |

Firebase **client** API keys are not as sensitive as Admin SDK JSON, but anyone can use an unrestricted key against your project. Rotation + restrictions are required after a public leak.

---

## Step 1 — Rotate keys (do this first)

1. Open [Google Cloud Console](https://console.cloud.google.com/) → project **logic-sprint**.
2. **APIs & Services** → **Credentials**.
3. Find the API keys used by your Android and iOS Firebase apps.
4. For each key:
   - **Regenerate key** (or create a new key and delete the old one).
   - **Application restrictions**:
     - Android: package `com.logicsprint.logic_sprint` + your release/debug SHA-1.
     - iOS: bundle id `com.logicsprint.logicSprint`.
   - **API restrictions**: limit to Firebase-related APIs only.
5. In [Firebase Console](https://console.firebase.google.com/) → Project settings → your apps → download fresh `google-services.json` and `GoogleService-Info.plist`.

---

## Step 2 — Local config (not in git)

This repo **gitignores** real Firebase client files:

```text
lib/firebase_options.dart
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

Setup on a machine that needs Firebase:

```bash
cp lib/firebase_options.dart.example lib/firebase_options.dart
# Edit with new keys from Firebase Console, or:
dart run flutterfire_cli:flutterfire configure
```

Copy platform files from Firebase Console into:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

---

## Step 3 — Firebase / Firestore hardening

- Enable **Firebase App Check** for Firestore (when using leaderboard).
- Review **Firestore rules** (`firestore.rules`) — already deny-by-default except leaderboard writes.
- Ensure **no Admin SDK JSON** is committed (`credentials/` is gitignored).

---

## Step 4 — GitHub alerts

After rotation and pushing the commit that **removes** keys from the repo:

1. Close or resolve secret scanning alerts #1 and #2.
2. If alerts persist on old commits, they refer to **history** — keys are still invalid if rotated.
3. Optional full history scrub (only if required by policy):

```bash
# Advanced — rewrites history; coordinate with all clones
git filter-repo --path lib/firebase_options.dart --invert-paths
```

---

## Branches without Firebase

`develop` and `feature/new-memory-games` do **not** include `firebase_options.dart`. The leak is from the Firebase feature branch only.

Do not merge Firebase config with real keys into `develop` until keys are rotated and files stay gitignored.

---

## Checklist

- [ ] Rotated Android API key in Google Cloud
- [ ] Rotated iOS API key in Google Cloud
- [ ] Applied key restrictions (app + API)
- [ ] Regenerated `google-services.json` / `GoogleService-Info.plist` locally
- [ ] Created local `lib/firebase_options.dart` (not committed)
- [ ] Pushed branch with secrets removed from tracking
- [ ] Resolved GitHub secret scanning alerts
