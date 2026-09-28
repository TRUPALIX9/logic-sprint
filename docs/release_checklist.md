# LogicSprint Release Checklist (v1.0.0, Google Play)

## 1. One-time setup (you)

### Google Play Console
- [ ] Developer account created (one-time $25 fee; new personal accounts must run a **closed test with 12+ testers for 14 days** before production access)
- [ ] App created: **LogicSprint: Brain Games**, package `com.trupal.logicsprint`, free, contains ads
- [ ] Play App Signing enabled (default) — you upload with the upload key below

### Upload keystore
- [x] `android/upload-keystore.jks` + `android/key.properties` created — [android_release_signing.md](android_release_signing.md)
- [ ] Keystore and passwords backed up in a password manager

### AdMob
- [x] AdMob app `ca-app-pub-4460198288175671~6905071306` with a **banner** unit and a **rewarded** unit ("Game Life Reward Ad", 1 reward = one more life)
- [x] `config/admob.json` filled locally (gitignored); template in [config/admob.example.json](../config/admob.example.json)
- [ ] Link the AdMob app to the Play listing once the app exists in Play Console
- [ ] AdMob → Privacy & messaging → **GDPR** message published (drives the in-app consent form)
- [x] Rewarded interstitial unit for the Ranks "Refresh ▶" (`ca-app-pub-4460198288175671/7272574609`) → `ADMOB_REFRESH_INTERSTITIAL_ID` in `config/admob.json`
- [x] GitHub secret `ADMOB_CONFIG_JSON` set from `config/admob.json` (all four IDs)
- [x] GitHub secrets `ANDROID_KEYSTORE_BASE64` (from `android/upload-keystore.jks`) and `ANDROID_KEY_PROPERTIES` (from `android/key.properties`) set for the release workflow
- [ ] `assets/brand/store/app-ads.txt` hosted at https://logicsprint.trupalpatel.com/app-ads.txt (and https://trupalpatel.com/app-ads.txt), and that site set as the Website in Play Console

### AppLovin (later: bidding through AdMob mediation; not in 1.0)
- [ ] Code: upgrade `google_mobile_ads` to ^9.1.0 (the banner uses `AdSize.getLargeAnchoredAdaptiveBannerAdSize`), add `gma_mediation_applovin`, and update the privacy policy and Data safety to name AppLovin
- [ ] AppLovin account created; copy **SDK Key** and **Report Key** (Account → Keys)
- [ ] AdMob → Mediation → mediation group for **Rewarded** (Android) → add ad source **AppLovin (bidding)** with the keys
- [ ] AdMob → Privacy & messaging → GDPR → ad partners: add **AppLovin Corp.** (also for US state regulations)
- [ ] app-ads.txt: add the lines from AppLovin → Account → App-ads.txt Info
- [ ] Test with AppLovin test mode and AdMob Ad Inspector (single ad source), then turn test mode off

### Supabase leaderboard
- [x] Project reachable (`axucnwnzuhdsiggqyjqf`)
- [x] Anonymous sign-ins enabled (Authentication → Providers)
- [x] [supabase/schema.sql](../supabase/schema.sql) run (profiles, game_bests, RLS, `claim_name` / `record_run` / `my_rank`, views `leaderboard_top`, `player_stats`, `game_stats`) — verified: views readable, direct writes and anonymous RPC calls refused
- [x] Re-run [supabase/schema.sql](../supabase/schema.sql) for name tags (`profiles.tag`, `claim_name(text, integer)`, `free_tag`) and the `leaderboard_ranked` view — the new build needs them; older builds keep working
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
| Advertising ID | Yes (the Mobile Ads SDK adds `AD_ID`). Purposes: Advertising or marketing, Analytics, Fraud prevention, security and compliance |
| Target audience | 13+ (keeps the app out of the Families program, whose ad rules differ) |
| Content rating | IARC questionnaire — no violence; user content limited to display names |
| Data safety — collected | Device or other IDs (advertising ID, via AdMob); App activity: app interactions (ads); Name: user-chosen display name (optional, leaderboard) |
| Data safety — purpose | Device or other IDs: Advertising or marketing, Analytics, Fraud prevention (AdMob). Name and game stats: App functionality (leaderboard) |
| Data safety — encrypted in transit | Yes |
| Data safety — deletion | Users can request leaderboard deletion by email |
| Privacy policy URL | Hosted policy from step 1 |

## 4. Store listing

- [ ] Copy from [assets/brand/docs/store_listing.md](../assets/brand/docs/store_listing.md)
- [ ] Icon: `assets/brand/store/google_play/play_store_icon_512.png`
- [ ] Feature graphic: `assets/brand/store/google_play/feature_graphic_1024x500.png`
- [ ] 8 phone screenshots from `assets/brand/store/google_play/screenshots/` (9:16), in the order listed in store_listing.md

## 5. QA smoke test (release build on a real device)

1. Cold launch → splash → Play tab; consent form appears once (EEA VPN or AdMob test device)
2. Rocket Launch: pick each ship in the sheet (Rocket, UFO, Spaceship, Missile) and it's the one you fly; the ship follows your finger; asteroids speed up gradually; at 1250 points the ship, then the rocks, then space change colour with a "Level 2" banner; one hit ends the run
3. Memory Lane on each difficulty: while the pattern plays the grid corners are red and the strip says "Watch · don't tap"; then the corners turn teal and "Your turn · repeat it X/Y" counts taps; each level replays the same pattern plus one new tile, a little faster; levels go on until a wrong tap
4. Quick Math on each difficulty: correct turns teal; a wrong answer turns coral, reveals the answer and ends the run; problems get harder every 10
5. Guess Color: the COLOR | TEXT switch lights the active rule and pulses when it flips; buttons shuffle, then their labels stop matching their colors; the countdown bar shrinks; a wrong tap or timeout ends the run; no time is shown anywhere
6. In every game the top bar is `||`, a banner (16 px clear of the button) and the score; `||` pauses and becomes ▶, which resumes; the phone's back button pauses (never quits); End run on the paused card goes to Result. From a score of 50 a mistake offers a revive (heart or ad), up to 3 per run; "End run" goes to Result
7. Result shows score and correct count, plus run time for Memory Lane / Quick Math (Best for the other two); banner shows on the Play tab
8. First Result without a name shows "Join the Global Top 10" → Set name with a 4-digit code ("Find a free code" fills one) → a taken name + code is refused, a free one is saved; Ranks shows "Updated … · daily 00:00 UTC", a next-update countdown, and "Refresh ▶" plays the rewarded interstitial and then refreshes, with a 30 min cooldown; the next run shows "Global rank #N" and Ranks marks your row "YOU" (or pins it below the Top 10); airplane mode shows "Saved on this phone · Offline — will sync later", and the run syncs on the next launch
9. Profile shows your name (Edit works), runs played, bests with play counts, and History; Settings → Reset high scores clears the bests
10. Settings footer shows `1.0.0 (1)`; Privacy policy screen shows the current text

## 6. Release
- [ ] Upload AAB to **Internal testing**, then closed testing, then production
- [ ] Tag `v1.0.0` on `production` and push the tag
