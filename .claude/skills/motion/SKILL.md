---
name: motion
description: "Add animation that feels intentional and stays fast: shared presets, thin wrapper components, reduced-motion support, transform/opacity only, and heavy libraries loaded only where used. Use when adding reveals, hover effects, page transitions, scroll-driven scenes, counters or marquees, or when animation is janky or hurts Lighthouse."
---

# Motion

Motion explains change: where something came from, what it relates to, what
just happened. If it explains nothing, cut it.

## 1. Presets, not ad-hoc values

Keep one presets file (`lib/ui/` — today `lib/ui/reveal.dart` holds the
fade-and-grow `Reveal`) with named recipes, e.g.
`fadeUp`, `stagger`, `reveal`, `parallax`, plus durations and easings.
Each theme or product picks a **feel**:

| Feel | Durations | Easing | Use for |
|---|---|---|---|
| Calm | 200–400 ms | ease-out | studio, content sites |
| Playful | spring, slight overshoot | spring | games, consumer apps |
| Precise | 120–200 ms | sharp ease-in-out | tools, dashboards |

Logic Sprint uses **Precise** inside games (180 ms swaps, `Curves.easeOutCubic`)
and **Playful** only for celebrations (new best, rank climb, loading screen).

## 2. Thin wrappers

Pages assemble wrappers instead of calling libraries directly:
`<Reveal>`, `<Stagger>`, `<ScrollScene>` (pin + scrub), `<Marquee>`, `<Counter>`.
Swapping a library later touches only the wrappers.

## 3. Reduced motion is a first-class design

- Read `prefers-reduced-motion` (in Flutter: `MediaQuery.disableAnimationsOf`).
- When set: no parallax, no smooth-scroll hijack, no auto-play, no large
  movement. Fades ≤ 150 ms or none.
- The reduced version must still look **finished**, not broken.
- Timers that matter to play (countdowns, revive offer) must never get shorter
  under reduced motion: use `AnimationBehavior.preserve`.

## 4. Performance

- Animate only `transform` and `opacity`. Never width/height/top/left/margin.
- Heavy libraries (scroll timelines, 3D, Lottie) load via dynamic import only on
  pages that use them.
- No layout thrash: read then write; avoid animating during scroll handlers
  without rAF/IntersectionObserver.
- Target 60 fps on a mid-range phone (profile in Flutter DevTools).
- The LCP element is real HTML text/image, never behind an entrance animation.

## 5. Taste rules

- One hero moment per page; everything else is quiet.
- Enter: ease-out. Exit: ease-in and faster than enter.
- Stagger lists by 30–60 ms; cap the total under ~600 ms.
- Hover feedback ≤ 150 ms. Never delay a click response for an animation.
- Scroll-pinned sections only where they tell a story; never on every section.
- Nothing flashes more than 3 times per second.

## Review checklist

- [ ] Uses presets and wrappers only
- [ ] transform/opacity only
- [ ] Reduced-motion path checked on a device or simulator
- [ ] Heavy libs dynamically imported
- [ ] 60 fps in a performance trace

## Customize for your project

Motion lives in `lib/ui/`; library: Flutter's own animation APIs (no
third-party animation package). Feel per area as described in section 1.
