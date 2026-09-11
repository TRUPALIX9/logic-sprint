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
- [x] AdMob app `ca-app-pub-4460198288175671~6905071306` with a **banner** unit and a **rewarded** unit ("Game Life Reward Ad", 1 reward = one more life)
- [x] `config/admob.json` filled locally (gitignored); template in [config/admob.example.json](../config/admob.example.json)
- [ ] Link the AdMob app to the Play listing once the app exists in Play Console
- [ ] AdMob → Privacy & messaging → **GDPR** message published (drives the in-app consent form)
- [ ] `app-ads.txt` hosted on the developer website listed in Play Console

### Supabase leaderboard
- [x] Project reachable (`axucnwnzuhdsiggqyjqf`)
- [ ] [supabase/schema.sql](../supabase/schema.sql) pasted into the SQL editor and run (table, RLS, per-board index, run time column; allows all four games) — the table doesn't exist yet
- [ ] Database password rotated (it was shared in chat)

### Privacy policy
- [x] Support email (trupal.work@gmail.com) in [assets/brand/docs/privacy_policy.md](../assets/brand/docs/privacy_policy.md)
- [ ] Policy hosted at a public URL (e.g. GitHub Pages) and entered in Play Console

## 2. Build

```bash
make check
make build-aab   # → build/app/outputs/bundle/release/app-release.aab
```

Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`, which builds the same and needs repo secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_PROPERTIES` and `ADMOB_CONFIG_JSON` (see [git_workflow.md](git_workflow.md)).

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
2. Rocket Launch: rocket follows your finger; green asteroids speed up the longer you last; one hit ends the run
3. Memory Lane on each difficulty: "Repeat the pattern X/Y" counts taps; levels go on until a wrong tap
4. Quick Math on each difficulty: correct turns teal; a wrong answer turns coral, reveals the answer and ends the run; problems get harder every 10
5. Guess Color: 4 colors, then 6, then shuffled buttons, then mismatched names and tints; a wrong tap ends the run
6. On the first mistake, "Watch ad · +1 life" appears once per run; watching it continues the run, "End run" goes to Result; a second mistake goes straight to Result
7. Result shows score, correct count and run time; banner shows on the Play tab
8. Post a score → Ranks opens on that game's board with your row marked "YOU"; airplane mode shows the offline message within ~8 s
9. Profile shows your display name and bests; Settings → Reset high scores clears them
10. Settings footer shows `1.0.0 (1)`; Privacy policy screen shows the current text

## 6. Release
- [ ] Upload AAB to **Internal testing**, then closed testing, then production
- [ ] Tag `v1.0.0` on `production` and push the tag
