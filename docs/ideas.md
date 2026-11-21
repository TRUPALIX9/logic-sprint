# Game ideas

Every Logic Sprint game follows the same rules: one screen, an endless run, one mistake
ends it (up to 3 revives), it gets harder as you go, and it trains one skill with one
accent colour. Use this list when picking what to build next.

## Skills covered today

| Game | Skill | Accent |
|---|---|---|
| Rocket Launch | Reflex | blue |
| Memory Lane | Memory | aqua |
| Quick Math | Arithmetic | teal |
| Guess Color | Focus | violet |
| Angle Sense (building, `design/plans/guess_angle_plan.html`) | Spatial | gold |
| Line Split (building, game 6, `design/plans/line_split_plan.html`) | Estimation | pink |

Not covered yet: **Logic**, Language, Timing, Perception.

## Saved for later

| Idea | Skill | The game in one line | Size | Notes |
|---|---|---|---|---|
| True or False | Logic | Shapes and one sentence; tap TRUE or FALSE. | M | First Logic game; see below. Prototype in `design/plans/true_or_false_plan.html`. |
| Next in Line | Logic | A sequence of numbers or shapes; pick what comes next from four. Patterns go from +2 to alternating and nested rules. | M | Second logic game if True or False does well. |
| Odd One Out | Logic | Four items; three share a rule; tap the one that doesn't. | S | Pairs well with the True or False scene generator. |
| Balance | Logic | A beam with weights at distances: tips left, right or stays level? | M | Reuses Angle Sense drawing code. |
| Word Flash | Language | A scrambled word flashes; tap its letters in order. Longer words, shorter flashes. | M | Needs a word list per language; English first. |
| Missing Letter | Language | A word with one gap; pick the letter from four. | S | Same word list as Word Flash. |
| Time Sense | Timing | Hold, then release when you think 3.00 s has passed. No clock on screen. Window ±250 ms shrinking to ±60 ms. | S | Very cheap; good filler game. |
| Rhythm Tap | Timing | A beat plays for four counts, then goes silent; keep tapping in time. | M | Needs sound on; offer a vibration mode. |
| Dot Count | Estimation | A cloud of dots flashes for half a second; call the count within ±10%. | S | Reuses Angle Sense's tape input. |
| Bigger Area | Perception | Two different shapes; tap the one with more area. The difference shrinks from 30% to 4%. | S | |
| Odd Shade | Perception | A grid of same-colour tiles with one slightly different; tap it. The difference shrinks. | S | Must check colour-blind safety (vary lightness, not hue only). |
| Mirror or Turn | Spatial | Is the right shape the left one rotated, or mirrored? | M | Spatial is taken by Angle Sense; keep for later. |
| Spot the Change | Focus | A scene flickers; one thing changes; tap it. | M | |
| Path Recall | Memory | A path snakes across a grid, then hides; trace it back. | M | Close to Memory Lane. |
| Maze Run | Spatial memory | See below. | M | Grew out of Route Bearing; kept for later. |

## Maze Run (saved idea, grown from Route Bearing)

Route Bearing on its own ("point at a landmark") was too close to Angle Sense's compass
round. This version makes it feel real: you follow something through a maze and then
have to say where it went.

- **What you see:** a top-down maze. A small glowing rover (or a mouse) leaves the start
  and moves slowly along the corridors, turning at junctions.
- **What you do:** follow it with your eyes. When it stops, the maze goes dark, and you
  answer one question:
  1. **Where is it now?** Tap the cell (early levels).
  2. **Which way is the start from here?** Turn a dial to point back home: real dead
     reckoning, scored in degrees like Angle Sense.
  3. **Which exit did it take?** Pick one of four doors (later levels, bigger mazes).
- **How it gets harder:** longer routes, more turns, a faster rover, and fog that hides
  more of the maze while it moves. From the middle levels the maze stays dark while it
  moves and only the rover's trail is lit for a moment.
- **Why it's different:** it trains holding a route in your head (spatial working
  memory), which no other game does. Memory Lane is order, Angle Sense is angles, and
  this is "where am I after all those turns?".
- **Reuses:** Angle Sense's dial and degree scoring for the "point home" question,
  Memory Lane's watch-then-answer rhythm, and the get-ready countdown.
- **Open questions:** the maze generator (a seeded recursive-backtracker keeps it fair
  and replayable), and whether the rover's speed should depend on difficulty or on
  question number.

## True or False (saved idea, Logic)

Moved out of the release plan on 2026-11-20: Angle Sense and Line Split ship first.

Full plan with a playable prototype: `design/plans/true_or_false_plan.html`.

The app is called LogicSprint and has no logic game. This one also carries the
trueorfalse.dev name.

- **What you see:** a small scene (a few coloured shapes on a grid) and one statement
  about it, for example "Every red shape is a square."
- **What you do:** tap TRUE or FALSE. Two big buttons, one rule, very fast to learn.
- **How it gets harder, by question number:**
  1. 1–8: plain facts. "There are 3 circles."
  2. 9–16: all / some / none. "Some blue shapes are triangles."
  3. 17–25: NOT. "No square is yellow."
  4. 26–35: AND / OR. "Every circle is red or big."
  5. 36–50: IF … THEN. "If a shape is blue, it is a square."
  6. 51+: two scenes, one statement ("In both boxes…"), plus a per-question timer
     that shrinks from 5 s to 2.5 s.
- **Easy / Medium / Hard:** Easy stops at stage 3 and has no timer. Medium is as above.
  Hard starts at stage 2 with the timer from question 1.
- **Fair for humans:** a true/false guess is right half the time, so a coin-flipper
  would survive about 1 question. Scenes are generated so the answer can't be read off
  a single glance at one shape: every statement is checked by code, and about half are
  true.
- **Reuses:** the `RoundEngine` run/revive/countdown flow, Guess Color's two-rule
  layout, the get-ready countdown, and the share card.
- **Accent:** a new orange (#FF8A3D). Coral stays reserved for errors.
- **Size:** M. The statement generator plus its truth checker is the real work. Build it
  as pure Dart with heavy tests.
