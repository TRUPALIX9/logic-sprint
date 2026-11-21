---
name: ui-hig
description: "Design or review an interface against Apple Human Interface Guidelines, Material 3 and the Laws of UX (Fitts, Hick, Jakob, Miller, Doherty, Tesler). Use when designing a new screen, reviewing a layout, choosing navigation or controls, sizing touch targets, or when a UI \"feels off\" but nobody can say why."
---

# UI: HIG, Material 3 and the Laws of UX

Use the platform's conventions unless you have a strong reason not to. Users
spend most of their time in other apps (Jakob's law).

## Laws of UX, as checks

| Law | What it means | Check |
|---|---|---|
| **Fitts** | Time to hit a target grows with distance and shrinks with size. | Primary actions big and near the thumb/cursor; destructive actions not next to frequent ones. |
| **Hick** | Decision time grows with the number of choices. | ≤ 1 primary action per view; group or progressively disclose the rest. |
| **Jakob** | Users expect your app to work like others. | Standard nav, icons, gestures and placement for the platform. |
| **Miller** | Working memory holds ~7±2 chunks. | Chunk long numbers, group fields, keep menus short. |
| **Doherty** | Feedback under ~400 ms keeps people in flow. | Optimistic UI or a visible state change within 100–400 ms. |
| **Tesler** | Complexity can't vanish, only move. | Move it to the system (good defaults, auto-fill), not the user. |
| Aesthetic-usability | Polished UI is perceived as easier. | Not an excuse to skip usability fixes. |
| Von Restorff | The different thing is remembered. | Only one thing is visually loud. |
| Proximity / common region | Near or enclosed = related. | Spacing and cards express grouping. |

## Touch and pointer targets

| Platform | Minimum |
|---|---|
| Apple HIG | 44×44 pt |
| Material 3 | 48×48 dp |
| Web (WCAG 2.2 AA 2.5.8) | 24×24 CSS px minimum, 44×44 recommended |

Spacing between adjacent targets ≥ 8 px. Visual size may be smaller than the hit area.

## Hierarchy

- One clear title per screen; heading levels follow visual weight.
- One filled primary button; secondary = tonal/outlined; tertiary = text.
- Type scale from the design system only; ≤ 3 sizes per view is a good target.
- Alignment on a grid; consistent left edges beat centred everything.

## Platform conventions

- **Apple:** tab bar ≤ 5 items for top-level sections; nav bar with back on the
  left; sheets for focused tasks; SF Symbols; respect safe areas and Dynamic Type.
- **Material 3:** navigation bar (3–5 destinations) on compact, navigation rail
  on medium, drawer on expanded; FAB for the single main action; tonal
  surfaces for elevation; dynamic colour roles (primary, secondary, tertiary,
  surface, error).
- **Web:** links look like links; the logo goes home; the back button works;
  URLs reflect state.

## States every component needs

Default, hover (pointer), focus-visible, pressed/active, disabled, loading,
error, empty, selected. A data view also needs loading → empty → error → data.

## Copy

Sentence case. Buttons are verb + object ("Save changes"). Errors say what
happened and what to do next. No "OK"/"Submit" when a specific verb exists.

## Review output

One line per finding: `where — rule — problem — fix`.
Example: `Checkout footer — Fitts — "Pay" is a 28 px text link at top-left — make it a full-width 48 px primary button at the bottom`.

## Customize for your project

- Target platforms: iOS and Android phones (plus iPad inside `lib/ui/tablet_frame.dart`).
- Design system: "Circuit Noir" in `lib/core/theme.dart` (`LS` colours, `LSText`
  type) and `lib/ui/chamfer.dart` (chamfered corners; the app never uses rounded corners).
