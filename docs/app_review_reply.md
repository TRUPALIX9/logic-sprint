# App Review reply: Guideline 2.1 Information Needed (1.0.2 (6))

Apple asked for 6 things on September 30, 2026. Paste the reply below into App Store Connect →
App Review → Reply, attach the screen recording, and paste the same text (without the recording)
into **App Review Information → Notes** on the 1.0.2 version page. Notes are capped at 4000 characters;
this text fits.

## Screen recording

There's no physical iPhone available, so the recording was made on the **iOS Simulator** (iPhone 17,
iOS 26.5, the newest runtime installed in Xcode) from a debug build of the 1.0.2 (6) source, which
is why Google's "Test mode" ads appear. The reply says this plainly; Apple asked for a physical
device, so they may ask again. If they do, the only fix is recording on a real iPhone (borrowed, and
installed through TestFlight).

- File: `build/LogicSprint_AppReview_Demo.mp4` (4:43, 720 × 1566, ~10 MB; gitignored). Idle stretches
  longer than 1.8 s were shortened; nothing else is edited. Raw capture: `build/app_review_demo.mp4`
- Shows, in order: launch → Google's explainer → Apple's tracking prompt (Ask Not to Track) →
  Rocket Launch (ship picker, run, Result) → rewarded ad for a heart → Set name (a banned name is
  refused, then "Demo Player" is saved) → Guess Color (global rank #8) → Quick Math → Memory Lane
  (revive offer via rewarded ad) → Ranks → long-press a player → Report dialog (cancelled, so no real
  player was reported) → Profile → Settings → Delete leaderboard data → Profile shows "Not set yet"

## Reply / Notes text

```
Hello, and thank you for the review. Answers to each point:

1. SCREEN RECORDING
Attached. I don't currently have a physical iPhone, so it was recorded on the iOS Simulator (iPhone 17, iOS 26.5) from the same source as build 6; the ads say "Test mode" because non-App Store builds use Google's test ad units. It starts at launch and shows: the ad consent explainer and Apple's tracking prompt, all four games, earning a heart with a rewarded ad, setting a leaderboard name (an offensive name is refused by the filter), the Global Top 10, reporting another player's name (long-press a row, then Report; I cancel in the video so no real player is reported), and deleting the player's data in Settings.
The app has no registration, login or password. Each install gets an anonymous account in the background so scores can appear on the leaderboard; "Delete leaderboard data" removes that account and everything linked to it. There is no paid content and no In-App Purchase.

2. PURPOSE AND AUDIENCE
LogicSprint: Brain Games is a set of four short brain-training games for teens and adults who want a quick, focused mental workout in a spare minute:
- Rocket Launch (reflexes): steer a ship through an asteroid storm.
- Memory Lane (memory): repeat a growing sequence of flashing tiles.
- Quick Math (arithmetic): pick the right answer of four, against the clock.
- Guess Color (focus): tap the word's color or its meaning as the rule flips.
Each game is an endless run that gets harder until the first mistake. Personal bests and history stay on the device, and an optional global Top 10 per game gives players a goal to beat. The app is free and supported by ads.

3. HOW TO USE IT (no login or demo account needed)
- Play tab (center, default): tap a game, choose a difficulty or ship, then play. One mistake ends the run; up to 3 revives per run with a heart or an optional rewarded ad.
- Profile tab: bests and history per game; "Set name" to choose an optional leaderboard name. Names are checked against a word filter.
- Ranks tab: global Top 10 per game. Long-press another player's row to report an offensive name; names reported by several players are hidden automatically, and I review reports.
- Settings (gear icon on the Play tab): sound, vibration, privacy choices, privacy policy, and Data → "Delete leaderboard data", which permanently deletes the player's anonymous account, name and online scores.
The app works offline; runs are saved on the device and sent to the leaderboard when back online.

4. EXTERNAL SERVICES
- Supabase (supabase.com): anonymous authentication and the database for the leaderboard (display names and scores).
- Google AdMob, with Google's User Messaging Platform: banner ads, optional rewarded ads, the consent messages and the explainer before Apple's App Tracking Transparency prompt. If tracking is declined, ads are still shown but not personalized.
No payment processors, AI services or other data providers are used.

5. REGIONAL DIFFERENCES
The app works the same in all regions. The only difference is legally required ad consent: Google's consent message is shown in the EEA, UK and Switzerland, and a US state privacy message where applicable, both through Google's User Messaging Platform. The leaderboard is one global board.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. The app is not in a regulated industry and contains no protected third-party content. All games, art and code are my own; the fonts (Rajdhani, IBM Plex Sans, JetBrains Mono) are used under the SIL Open Font License.

Privacy policy: https://logicsprint.trupalpatel.com/privacy
Contact: Trupal Patel, trupal.work@gmail.com

Thank you.
```
