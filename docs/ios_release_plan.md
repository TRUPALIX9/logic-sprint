# LogicSprint iOS Release Plan (v1.0.2 on the App Store)

The Flutter code already runs on iOS. What's left is Apple setup, some iOS config, two
App Store review requirements (in-app data deletion, and moderation of leaderboard names)
and store assets. This file is the whole plan in order; tick items off as they're done.

## Status (September 29, 2026)

**Done in the repo, not yet committed:** everything in Phase 3 (iOS config, in-app deletion,
name moderation, score checks), App Store screenshots, listing copy, privacy policy, 1.0.2 notes.
**Waiting on:** Xcode + CocoaPods on this Mac, the Apple Developer payment to clear, the
iOS AdMob app, and running `supabase/schema.sql` on the live project.

**Fastest path to an uploadable bundle once the account is active:**

```bash
cp config/admob.example.json config/admob.ios.json   # fill in the 4 iOS AdMob IDs
make check
make build-ios                                        # → build/ios/ipa/LogicSprint.ipa
```

Then open `ios/Runner.xcworkspace` once to choose your Team (Signing & Capabilities) if the
build asks for it, and upload the `.ipa` with Transporter.

**Decisions made**

| Decision | Choice | Why |
|---|---|---|
| Devices | **iPhone and iPad** (`TARGETED_DEVICE_FAMILY = "1,2"`) | iPad runs full screen (`UIRequiresFullScreen`), portrait; `TabletFrame` scales the phone layout to fill it; 13" screenshots in `screenshots_ipad/` |
| Minimum iOS | 15.0 | App Store requires 15.0+ for uploads from April 2027 (warning 90068) |
| "Donate a view" | **Removed** (done) | Not needed; the word "donate" invites App Store guideline 3.1.1 questions |
| Builds | Local `flutter build ipa` + Xcode/Transporter upload | The GitHub release workflow runs on Ubuntu, which can't build iOS |
| Version | `1.0.2+4` for both stores (done in `pubspec.yaml`) | One version line; Android ships the same Dart code |

---

## Phase 0: Tonight (no Apple account needed)

- [x] Remove "Donate a view" (screen, Settings row, Hearts sheet button, state, storage, test, README, privacy policy)
- [x] Everything in Phase 3 that doesn't need the account (see Status)
- [ ] Install **Xcode** from the Mac App Store (large download; start it tonight)
- [ ] `sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild -license accept`
- [ ] `xcodebuild -runFirstLaunch` and install the iOS platform (Xcode → Settings → Components)
- [ ] `brew install cocoapods`
- [ ] `flutter doctor -v`: the Xcode and CocoaPods lines are green
- [ ] `flutter run` on the iOS Simulator: all four games, Ranks, Profile and Settings work (test ads)

## Phase 1: Tomorrow morning (Apple Developer Program)

- [ ] Enroll at https://developer.apple.com/programs/enroll/ ($99/year, **Individual**). Use the Apple ID you'll keep for the app. Approval is usually quick but can take up to 48 h (ID check)
- [ ] Note the **Team ID** (Membership details)
- [ ] Certificates, Identifiers & Profiles → Identifiers → register App ID `com.trupal.logicsprint` (no extra capabilities needed)
- [ ] App Store Connect → My Apps → **+ New App**: iOS, name **LogicSprint: Brain Games**, primary language English (U.S.), bundle ID `com.trupal.logicsprint`, SKU `logicsprint-ios`
- [ ] Agreements, Tax and Banking: accept the **Free Apps** agreement (the Paid Apps agreement isn't needed, since there are no in-app purchases)

## Phase 2: AdMob for iOS (in parallel with Phase 1)

Android ad units don't serve on iOS; iOS needs its own AdMob app.

- [x] AdMob → Apps → Add app → **iOS** (`ca-app-pub-4460198288175671~3620726902`), "not listed yet" (link it to the store once live)
- [x] Create 3 units, matching Android: **Banner**, **Rewarded** ("Game Life Reward Ad", 1 reward), **Rewarded interstitial** (Ranks refresh)
- [x] Create `config/admob.ios.json` (gitignored, same keys as `config/admob.json`) with the iOS app ID and unit IDs. `ADMOB_APP_ID` is written into Info.plist by the "AdMob App ID" build phase; a release build fails without it
- [ ] AdMob → Privacy & messaging:
  - [ ] GDPR message: add the iOS app
  - [ ] **IDFA explainer** message: create and publish it (it's shown before Apple's tracking prompt)
  - [ ] US state regulations message: add the iOS app
- [ ] Add the iOS app ID line to `assets/brand/store/app-ads.txt` and re-host it at https://logicsprint.trupalpatel.com/app-ads.txt

## Phase 3: Code and config changes

### 3a. iOS project config ✅

| # | File | Change | Status |
|---|---|---|---|
| 1 | `ios/Runner/Info.plist` + "AdMob App ID" build phase | `GADApplicationIdentifier` keeps Google's test ID in the file; every build replaces it with `ADMOB_APP_ID` from the dart-defines (same approach as `android/app/build.gradle.kts`). Release builds fail without it | ✅ |
| 2 | `Info.plist` | `SKAdNetworkItems` with Google's ID (`cstr6suwn9`). Add the third-party buyer list from https://developers.google.com/admob/ios/3p-skadnetworks for more ad demand | ✅ (Google only) |
| 3 | `Info.plist` | `NSUserTrackingUsageDescription` (tracking prompt kept: Allow = personalized ads, Ask Not to Track = non-personalized ads, still paid) | ✅ |
| 4 | `Info.plist` | `ITSAppUsesNonExemptEncryption = false` | ✅ |
| 5 | `Info.plist` | Portrait only (iPad: portrait both ways, `UIRequiresFullScreen`) | ✅ |
| 6 | `Runner.xcodeproj` | `TARGETED_DEVICE_FAMILY = 1` (iPhone) in all configurations | ✅ |
| 7 | `Runner.xcodeproj` | Signing team: set in Xcode once the account is active | ⏳ you |
| 8 | `ios/Runner/PrivacyInfo.xcprivacy` | App privacy manifest (name + gameplay content for app functionality, UserDefaults `CA92.1`); added to the Runner target | ✅ |
| 9 | `ios/Podfile` | Generated by the first `flutter build ios` (needed for `google_mobile_ads`, which has no Swift Package yet); commit it with `Podfile.lock` | ⏳ first build |
| 10 | `Makefile` | `make build-ios` uses `config/admob.ios.json` and stops if it's missing | ✅ |
| 11 | `pubspec.yaml` | `version: 1.0.2+4` | ✅ |

### 3b. App Tracking Transparency (kept)

Google's UMP SDK shows the IDFA explainer, then Apple's prompt. **Allow** → personalized ads
(higher revenue); **Ask App Not to Track** → ads still show, not personalized with the IDFA
(lower revenue). Nobody is opted out by default. Remaining: keep the IDFA explainer published
in AdMob, and answer **Yes** to "used for tracking" for Device ID, Product Interaction and
Advertising Data in App Privacy.

### 3c. In-app data deletion ✅

- `delete_my_data()` in `supabase/schema.sql` deletes the caller's `auth.users` row; profile, bests and reports cascade
- `Leaderboard.deleteMyData()` waits for any sync in flight, calls the RPC, drops the local session, then forgets the name, tag, unsent runs and cached boards (local bests and History stay)
- **Settings → Data → Delete leaderboard data**, with a confirm dialog; offline shows an error and keeps everything

### 3d. Leaderboard name moderation ✅

- `banned_words` table (seeded; add rows in the dashboard) checked by `claim_name` after folding look-alikes (`0→o 1→i 3→e 4→a 5→s 7→t @→a $→s`, spaces/_/- dropped). The app shows "That name isn't allowed — try another."
- **Report:** long-press another player's row on Ranks → confirm → `report_name(player)`. Three different reporters hide the name (`profiles.hidden`) from every public view until the player picks a new name
- Review reports in the dashboard: `select * from name_reports`; un-hide with `update profiles set hidden = false where id = '…'`

### 3e. Leaderboard hardening ✅ (partly)

- `record_run` counts implausible runs as plays but never as bests: timed games (Memory Lane, Quick Math) must stay under 100 + 60 points per second of run time; Rocket Launch and Guess Color are capped at 50 000. No error is raised, because the app would retry a refused run forever
- **Not done, on purpose:** a per-minute rate limit (it would stall the offline queue, and one fake call is all a cheater needs anyway) and removing `player_id` from the public views (the live 1.0.1 Android app uses it to mark "YOU")

### 3f. Apply the database changes (you, before the iOS build goes to review)

1. Supabase dashboard → SQL Editor → paste all of `supabase/schema.sql` → Run (safe to re-run; 1.0.1 Android builds keep working)
2. Check it (SQL Editor):

```sql
select name_is_banned('SH1T_head') as should_be_true,
       name_is_banned('Grape Fox') as should_be_false,
       name_is_banned('NEON_FOX')  as should_be_false;
select count(*) from banned_words;                       -- 31
select column_name from information_schema.columns
 where table_name = 'profiles' and column_name = 'hidden'; -- 1 row
```

3. In the app (debug build): set a name, long-press your row from a second device/simulator to report it, then Settings → Delete leaderboard data. The name leaves the Top 10 and `select count(*) from profiles where id = '<old id>'` is 0. If the delete fails with a permission error on `auth.users`, the function's owner isn't `postgres`: run `alter function public.delete_my_data() owner to postgres;`
4. Dashboard → Advisors → Security Advisor: no errors

## Phase 4: Store listing and documents

- [x] **Screenshots: 6.9" iPhone, 1320 × 2868**, 9 of them, no alpha → `assets/brand/store/app_store/screenshots/` (`SCREENSHOTS=appstore`, see README)
- [ ] App icon: 1024 × 1024, no alpha (already produced by `flutter_launcher_icons` with `remove_alpha_ios`)
- [x] Listing copy in `assets/brand/docs/store_listing.md`, new App Store section (also has App Review notes and App Privacy answers):
  - Name (30): `LogicSprint: Brain Games`
  - Subtitle (30): e.g. `Reflex, memory & math games`
  - Keywords (100, comma separated, no spaces)
  - Promotional text (170), description (4000), What's New
  - Support URL and Marketing URL: https://logicsprint.trupalpatel.com
- [x] **Privacy policy** covers iOS (IDFA, the tracking prompt, iOS Settings → Tracking), in-app deletion and name reporting; it's bundled in the app too
- [ ] Host the updated policy and set its URL in App Store Connect
- [ ] **App Privacy** questionnaire in App Store Connect:

| Data type | Linked to user | Used for tracking | Purpose |
|---|---|---|---|
| Device ID (IDFA) | No | **Yes** | Third-party advertising, Analytics |
| Product interaction | No | Yes | Third-party advertising, Analytics |
| Advertising data | No | Yes | Third-party advertising |
| Name (leaderboard display name) | Yes | No | App functionality |
| Gameplay content (scores) | Yes | No | App functionality |

- [ ] Age rating questionnaire: no violence, no gambling, **user-generated content: yes (names)**, which gives 12+ or 13+; that matches Android's 13+ target
- [ ] Category: Games → Puzzle (secondary: Games → Casual)
- [ ] App Review notes: "No login. Players sign in anonymously; a name is optional. Delete data: Settings → Privacy → Delete my leaderboard data. Report a name: long-press a row on Ranks."

## Phase 5: Build, TestFlight and QA

```bash
make check
make build-ios   # → build/ios/ipa/*.ipa
```

- [ ] Upload with **Transporter** (Mac App Store), or open `build/ios/archive/Runner.xcarchive` in Xcode → Distribute App
- [ ] Wait for processing (about 15–30 min), then TestFlight → internal testing → install on your iPhone
- [ ] Run the QA smoke test in `docs/release_checklist.md` §5, plus these iOS-specific checks:
  - [ ] The tracking prompt appears once, after the IDFA explainer; ads load when it's allowed and when it's denied
  - [ ] Real ads (not test ads) show on banner, rewarded and Ranks refresh
  - [ ] Swipe-from-edge back gesture during a run pauses the run and never quits it (Android's back button does the same)
  - [ ] Home indicator and Dynamic Island don't overlap the game top bar or the Rocket Launch play area
  - [ ] Backgrounding the app during a run pauses it
  - [ ] Delete my leaderboard data: the name disappears from Ranks, and a new run creates a fresh player
  - [ ] Offline mode: no ads, "Saved on this phone", and the run syncs on the next launch
  - [ ] Settings footer shows `1.0.2 (4)`

## Phase 6: Submit

- [ ] Select the TestFlight build on the 1.0.2 version page, fill in every section above, **Add for Review**
- [ ] Release option: **Manually release** (you choose when it goes live after approval)
- [ ] Review usually takes 1–3 days. Common first-time rejections for this app: missing in-app deletion (3c), UGC moderation (3d), missing tracking prompt text, and a privacy policy that doesn't mention iOS
- [ ] After release: link the AdMob iOS app to the App Store listing; update the README (Platform: Android + iOS)

## Phase 7: Later (optional)

- [ ] iOS in CI: a `macos-latest` job, a signing certificate plus provisioning profile (or an App Store Connect API key with automatic signing) as secrets, and `flutter build ipa` → upload to TestFlight
- [x] iPad support (13" screenshots, `TabletFrame` layout)

---

## Supabase access: what an anonymous player can do

**Short answer: no, they can't access the whole database.** An anonymous sign-in gets
the `authenticated` role (with `is_anonymous = true` in its token), and `supabase/schema.sql`
limits that role to the following. The only key in the app is the **publishable** key;
the secret key is only in your local `.env` and has never been committed.

| Anonymous player can | Anonymous player cannot |
|---|---|
| Read `profiles` and `game_bests` (all rows: they're the public leaderboard) | Insert, update or delete any table directly (RLS on, no write policies) |
| Read the views `leaderboard_top`, `leaderboard_ranked`, `player_stats`, `game_stats` | Change another player's name or scores (every function uses `auth.uid()`) |
| Call `claim_name`, `free_tag`, `record_run`, `my_rank` (for their own row only) | Read `auth.users`, emails, other schemas or storage |
| | Call any function without signing in (`anon` has no execute rights) |

**Real gaps to close (Phase 3e):**

1. **Score cheating.** `record_run` trusts the score it receives. The publishable key and
   project URL can be pulled out of the app, so anyone can sign in anonymously and post
   a score of 1 000 000 straight to the Top 10. Plausibility checks and a rate limit make
   this much harder (it can't be fully prevented in a client-only game).
2. **Unlimited anonymous accounts.** Each one can claim a name. Supabase limits anonymous
   sign-ins per IP (Authentication → Rate limits); keep that low. Name moderation (3d)
   covers the abuse side.
3. **`player_id` is public** in the leaderboard views. It's the player's auth user ID. It
   can't be used to act as them, but there's no reason to publish it.
4. **Future tables.** Supabase grants `anon`/`authenticated` full rights on new tables in
   `public` by default, so **every new table must `enable row level security`** in the
   same statement (the new `banned_words` and `name_reports` tables included).

The live database wasn't checked here; the Supabase MCP connection was refused permission.
Confirm the live project matches `schema.sql` with Dashboard → Advisors → **Security Advisor**,
and rotate the database password (still open in `release_checklist.md`).
