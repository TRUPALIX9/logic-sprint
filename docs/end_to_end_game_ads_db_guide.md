# LogicSprint: End-to-End Database and Ads Integration Guide

This guide details how **LogicSprint** functions as a fully connected, end-to-end mobile game with live advertising and global leaderboard database integration—while remaining **100% free to operate** without database billing surprises.

---

## 1. 100% Free Database Usage (Firebase Firestore)

LogicSprint is configured out-of-the-box to run under the **Firebase Spark (Free) Plan**, which provides generous daily limits:
- **Cloud Firestore Reads:** 50,000 / day
- **Cloud Firestore Writes:** 20,000 / day
- **Cloud Firestore Deletes:** 20,000 / day
- **Cloud Firestore Storage:** 1 GiB total

To protect you from ever exceeding these limits or incurring unexpected costs, we have implemented four layers of client-side optimization and query shielding:

### Layer A: Local-Only Filtering & Sorting
- Standard database designs run query filters against the backend (e.g., "Get only Easy difficulty Rocket Launch scores"). This generates new reads every time a user toggles a tab.
- **Our Solution:** LogicSprint fetches at most the **Top 100 scores globally** in a single query (`leaderboardScores` collection ordered by score descending). When the user toggles games or difficulty levels on the screen, **filtering and sorting are performed in local device memory (RAM) on the cached list!** This results in exactly **zero** additional database queries when switching tabs.

### Layer B: 10-Minute Cache Window (`LeaderboardCacheService`)
- The leaderboard screen does not trigger live listeners or stream real-time updates.
- Scores are cached locally on-device inside `shared_preferences` for **10 minutes**. Tapping or opening the Leaderboard screen during this window loads cached data instantly, generating **0 database reads**.

### Layer C: Manual Refresh Cooldown (60 Seconds)
- To prevent users from spamming the "Refresh" button and driving up read counts, we enforce a strict **60-second cooldown** after a manual refresh. Any refresh attempt within this window uses the cache and displays a polite tip showing when refresh is available again.

### Layer D: Daily Submission Limit (5 per Day)
- To prevent malicious bots or players from spamming writes to your Firestore database, each device is strictly rate-limited to a maximum of **5 leaderboard submissions per 24 hours**.
- Play remains fully active and high scores continue saving locally even if the daily leaderboard limit is reached.

---

## 2. Integrated Ads Monetization System (Google Mobile Ads)

We have built a dual-mode, non-intrusive ad system supporting both **Simulated (Test/Demonstration) Mode** and **Real AdMob SDK Mode**.

### Dual-Mode Architecture

| Feature | Simulated Mode (Default) | Real AdMob Mode |
|---------|-------------------------|-----------------|
| **Startup Behavior** | Safe, 100% offline, never crashes | Initialized safely, uses official Google SDK |
| **Inline Banners** | Interactive custom in-app promos (no SDK needed) | Live AdMob BannerWidget |
| **Interstitial Ads** | Beautiful, fullscreen skip-timer mock overlay | Live fullscreen AdMob interstitial popups |
| **Testing/CI** | Compiles & runs anywhere without native configs | Requires correct Android/iOS configurations |

### Switching Modes in App Settings
1. Launch LogicSprint and tap **Settings**.
2. Under "Preferences", locate the **Ads Mode** option.
3. Switch dynamically between:
   - **Simulated:** Displays beautiful interactive mock ads promoting "LogicSprint Premium" (fully functional with skip timers and CTAs).
   - **Real AdMob:** Switches to real Google Mobile Ads utilizing official test keys.
   - **Disabled:** Turns off all ads completely.

---

## 3. Launch Checklist: Going Live with Your Database and Ads

Follow this checklist when you are ready to compile, sign, and submit your game to the Google Play Store or Apple App Store.

### Step 1: Deploy Firestore Database & Rules
1. In the [Firebase Console](https://console.firebase.google.com/), select your project and click **Create Database** (under Cloud Firestore). Choose production mode and select your server location.
2. Deploy security rules from your repository root:
   ```bash
   firebase deploy --only firestore:rules
   ```
   *The pre-configured `firestore.rules` file allows public writes only for valid LogicSprint scores and protects database integrity.*

### Step 2: Configure Your Mobile Ads App IDs
Google AdMob requires you to register your App in their console and provide unique IDs.

#### A. Android Config (`android/app/src/main/AndroidManifest.xml`)
Replace our test Application ID with your real AdMob Android App ID inside the `<meta-data>` tag:
```xml
<!-- Replace this value with your real Android App ID from AdMob (resembles: ca-app-pub-1234567890123456~1234567890) -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

#### B. iOS Config (`ios/Runner/Info.plist`)
Replace our test Application ID with your real AdMob iOS App ID inside the `GADApplicationIdentifier` key:
```xml
<!-- Replace this value with your real iOS App ID from AdMob -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
```

### Step 3: Configure Your Ad Unit IDs (`lib/services/ad_service.dart`)
Once you create Ad Units in the AdMob Console (one banner and one interstitial for each platform), replace our static test keys with your production Keys:

```dart
// lib/services/ad_service.dart
// Inside class AdService:

// Replace these with your live AdMob Ad Unit IDs
static const String androidBannerUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
static const String iosBannerUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
static const String androidInterstitialUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
static const String iosInterstitialUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
```

---

## 4. Architectural Summary

- **Database Client:** `lib/services/leaderboard_service.dart` handles database submissions and list loading.
- **Ad Client:** `lib/services/ad_service.dart` acts as the single source of truth for loading, showing, and switching ads.
- **In-App Banner Widget:** `lib/widgets/ad_banner_widget.dart` is placed dynamically at the bottom of the Home and Game Select Screens.
- **End-of-Round Interstitial:** Located inside gameplay state handlers (`RocketLaunchScreen`, `MemoryLaneScreen`) to intercept transitions and present an interstitial ad before navigating to the result screen.

---

## 5. GitHub Actions Production CI/CD Release Pipeline

We have created an automated release workflow in `.github/workflows/release.yml` that builds and compiles your Android AAB and iOS IPA every time you push code to the `production` branch.

To make the build fully connected and automatically signed/configured with your Firebase database and Google AdMob, go to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions** -> **Repository secrets**, and add the following secrets:

### Required Firebase Config Secret
- `FIREBASE_SERVICE_ACCOUNT`: Copy and paste the entire JSON object of your Admin SDK service account (the one you provided).
  *Our CI/CD pipeline is fully automated—it will use this single service account to securely fetch your Android `google-services.json`, iOS `GoogleService-Info.plist`, and generate your real `lib/firebase_options.dart` files directly during compile time! There is no need to copy-paste multiple config files into your secrets.*

### Required Android Release Signing Secrets (Optional but recommended for Production)
- `ANDROID_KEY_PROPERTIES`: Copy and paste the contents of your `android/key.properties` file:
  ```text
  storePassword=YOUR_STORE_PASSWORD
  keyPassword=YOUR_KEY_PASSWORD
  keyAlias=upload
  storeFile=upload-keystore.jks
  ```
- `UPLOAD_KEYSTORE_JKS_BASE64`: Your Android keystore is a binary file and cannot be pasted as text. Run this terminal command to convert it to a safe Base64 string, and copy the output:
  - **macOS/Linux:** `base64 -i android/upload-keystore.jks`
  - **Windows (PowerShell):** `[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/upload-keystore.jks"))`

### Downloadable Build Artifacts
Once you push to `production`, GitHub Actions will spin up a macOS builder, restore all configurations, build the app, and generate:
1. **`logic-sprint-android-release`**: A production-ready Google Play `.aab` file.
2. **`logic-sprint-ios-release`**: A production-ready App Store `.ipa` folder.
You can download these files directly from the finished Action run summary!
