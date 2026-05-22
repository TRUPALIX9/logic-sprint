# Android Studio setup

Open the **Flutter project root** (`logic-sprint/`), not only the `android/` subfolder.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) on your `PATH`
- Android Studio with **Flutter** and **Dart** plugins ([install guide](https://docs.flutter.dev/get-started/editor?tab=androidstudio))
- Android SDK (via Android Studio → SDK Manager)

## One-time setup

```bash
cd logic-sprint
make setup          # flutter pub get
flutter doctor      # fix any Android toolchain issues
```

`android/local.properties` is created automatically by Flutter (contains `flutter.sdk` and `sdk.dir`). It is gitignored.

### Firebase (optional)

The repo includes **placeholder** `android/app/google-services.json` and `lib/firebase_options.dart` so Gradle sync works without secrets. For a working leaderboard locally:

```bash
./scripts/refresh_firebase_client_config.sh
```

Do **not** commit files after refresh if they contain real API keys.

### Release signing (Play Store only)

See [android_release_signing.md](android_release_signing.md). Debug builds do not need a keystore.

## Open in Android Studio

1. **File → Open** → select the `logic-sprint` folder (repository root).
2. Wait for **Gradle sync** to finish (status bar). If sync fails, run **File → Sync Project with Gradle Files**.
3. Confirm the Flutter SDK path: **Settings → Languages & Frameworks → Flutter** (or run `flutter doctor` in a terminal).

## Run the app

**Recommended (Flutter tooling):**

- Terminal: `make run` or `flutter run`
- Android Studio: main toolbar **device dropdown** → choose emulator/phone → **Run** (green play) on `lib/main.dart`

**Gradle-only (Android module):**

- Build variant: **debug**
- **Run → Run 'app'** on the `android` configuration

## Verify Gradle (same as Android Studio sync)

```bash
cd android
./gradlew :app:assembleDebug
```

Or from repo root:

```bash
flutter build apk --debug
```

## Common issues

| Symptom | Fix |
|--------|-----|
| `flutter.sdk not set in local.properties` | Run `flutter pub get` or `flutter build apk` once from repo root |
| `google-services.json is missing` | Pull latest; file should exist under `android/app/`. Or `cp android/app/google-services.json.example android/app/google-services.json` |
| Gradle sync slow / fails | **File → Invalidate Caches → Restart**; ensure JDK 17+ in **Settings → Build → Gradle** |
| No devices | **Tools → Device Manager** → create/start an AVD, or plug in a phone with USB debugging |

## Pre-push checks

```bash
make hooks-install   # once per clone
make check           # analyze + test (runs before git push)
```
