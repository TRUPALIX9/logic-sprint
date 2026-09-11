# LogicSprint Release Checklist (v1.0.0, Google Play)

## 1. One-time setup (you)

### Google Play Console
- [ ] Developer account created (one-time $25 fee; new personal accounts must run a **closed test with 12+ testers for 14 days** before production access)
- [ ] App created: **LogicSprint: Brain Games**, package `com.trupal.logicsprint`, free, contains ads
- [ ] Play App Signing enabled (default) — you upload with the upload key below

### Upload keystore
- [ ] `android/upload-keystore.jks` + `android/key.properties` created — [android_release_signing.md](android_release_signing.md)
- [ ] Keystore and passwords backed up in a password manager

### AdMob
- [ ] AdMob app linked to the Play listing; one **banner** and one **interstitial** unit created
- [ ] `config/admob.json` filled from [config/admob.example.json](../config/admob.example.json) (gitignored)
- [ ] AdMob → Privacy & messaging → **GDPR** message published (drives the in-app consent form)
- [ ] `app-ads.txt` hosted on the developer website listed in Play Console

### Supabase leaderboard
- [ ] Project reachable — the URL in `lib/core/config.dart` currently does not resolve; fix it in the Supabase dashboard or update the URL and publishable key
- [ ] [supabase/schema.sql](../supabase/schema.sql) run in the SQL editor (table, RLS, per-board index; allows all four games)

### Privacy policy
- [x] Support email (trupal.work@gmail.com) in [assets/brand/docs/privacy_policy.md](../assets/brand/docs/privacy_policy.md)
- [ ] Policy hosted at a public URL (e.g. GitHub Pages) and entered in Play Console

## 2. Build

```bash
make check
make build-aab   # → build/app/outputs/bundle/release/app-release.aab
```

CI (`.github/workflows/release.yml`) builds the same on pushes to `production` and needs repo secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_PROPERTIES` and `ADMOB_CONFIG_JSON`.

## 3. Play Console forms

| Form | Answer |
|------|--------|
| Ads | Yes, contains ads |
| Target audience | 13+ (keeps the app out of the Families program, whose ad rules differ) |
| Content rating | IARC questionnaire — no violence; user content limited to display names |
| Data safety — collected | Device or other IDs (advertising ID, via AdMob); App activity: app interactions (ads); Name: user-chosen display name (optional, leaderboard) |
| Data safety — purpose | Advertising or marketing, fraud prevention (AdMob); App functionality (leaderboard) |
| Data safety — encrypted in transit | Yes |
| Data safety — deletion | Users can request leaderboard deletion by email |
| Privacy policy URL | Hosted policy from step 1 |

## 4. Store listing

- [ ] Copy from [assets/brand/docs/store_listing.md](../assets/brand/docs/store_listing.md)
- [ ] Icon: `assets/brand/store/google_play/play_store_icon_512.png`
- [ ] Feature graphic: `assets/brand/store/google_play/feature_graphic_1024x500.png`
- [ ] 4–8 phone screenshots: Play tab, a game sheet, each of the four games, Result, Ranks

## 5. QA smoke test (release build on a real device)

1. Cold launch → splash → Play tab; consent form appears once (EEA VPN or AdMob test device)
2. Rocket Launch: rocket follows your finger; the storm speeds up; round ends on Result
3. Memory Lane on each difficulty: "Repeat the pattern X/Y" counts taps; level grows
4. Quick Math on each difficulty: correct answer turns teal, wrong turns coral and reveals the answer
5. Guess Color: 4 colors at first, 6 later, buttons reshuffle near the end
6. Interstitial after every 2nd round returns to Result; banner shows on the Play tab
7. Post a score → Ranks opens on that game's board with your row marked "YOU"; airplane mode shows the offline message within ~8 s
8. Profile shows your display name and bests; Settings → Reset high scores clears them
9. Settings footer shows `1.0.0 (1)`; Privacy policy screen shows the current text

## 6. Release
- [ ] Upload AAB to **Internal testing**, then closed testing, then production
- [ ] Merge `develop` → `production`, tag `v1.0.0`
