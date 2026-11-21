---
name: accessibility
description: "Build and review UI to WCAG 2.2 AA: semantics, keyboard, focus, contrast, labels, motion, forms and screen-reader behaviour. Use when building any interactive component, before shipping a page, when adding custom controls (switches, menus, dialogs, comboboxes), or when asked \"is this accessible?\"."
---

# Accessibility (WCAG 2.2 AA)

## 1. Native first

Use the real element: `<button>`, `<a href>`, `<input type="checkbox">`,
`<select>`, `<dialog>`, `<details>`. ARIA is for when no element exists, and
"no ARIA is better than bad ARIA". In Flutter: use real buttons and
`Semantics(button: true, label: ...)` on custom tappables.

## 2. Keyboard

- Everything clickable is reachable with Tab and works with Enter/Space.
- Logical tab order follows reading order; no positive `tabindex`.
- Composite widgets (tabs, menus, listboxes) use arrow keys inside, one tab stop.
- Esc closes overlays. No keyboard traps.
- A visible "Skip to content" link on pages with navigation.

## 3. Focus

- `:focus-visible` ring with ≥ 3:1 contrast; never `outline: none` without a replacement.
- Dialogs: move focus in on open, trap it, return it to the trigger on close.
- After route changes or async content, move focus or announce it.
- Focused items are not hidden behind sticky headers (2.4.11).

## 4. Names, roles, states

- Icon-only buttons get a label (`tooltip` / `Semantics(label:)` in Flutter).
- Inputs have a visible label; placeholders are not labels.
- Custom switch: `role="switch"` + `aria-checked`. Toggle button: `aria-pressed`.
  Disclosure: `aria-expanded` + `aria-controls`.
- Live updates (toasts, async results, game countdowns) use `role="status"` /
  `aria-live="polite"` (Flutter: `Semantics(liveRegion: true)`).

## 5. Contrast and colour

- Text ≥ 4.5:1; large text (≥ 24 px, or 18.66 px bold) ≥ 3:1.
- UI components and focus indicators ≥ 3:1 against neighbours.
- Never convey state by colour alone: add an icon, label or pattern
  (Guess Color answer buttons carry text labels for this reason).
- Logic Sprint ships dark only; check every accent on `LS.bg`, `LS.surface`
  and `LS.well`.

## 6. Motion

- Respect reduced motion: remove parallax, auto-play, large movement.
- Nothing flashes more than 3 times per second.
- Auto-moving content longer than 5 s has pause/stop.

## 7. Forms and errors

- Errors are text, next to the field, linked with `aria-describedby`, and say how to fix.
- Don't block paste; support autocomplete attributes.
- Don't require re-entering info already given (3.3.7); allow non-puzzle auth (3.3.8).

## 8. Targets and zoom

- Pointer targets ≥ 24×24 CSS px (2.5.8); 44 pt (iOS) / 48 dp (Android) recommended.
- Works at 200% text size without clipping.
- Drag actions have a single-pointer alternative (2.5.7) — e.g. Angle Sense's
  tape also has ±1 buttons.

## 9. Media and images

- Meaningful images have `alt`; decorative images use `alt=""`.
- Video has captions; audio has transcripts.

## Manual test script

1. Complete the main flow with VoiceOver (iOS) and TalkBack (Android).
2. Set the largest text size; check nothing clips.
3. Turn on reduce motion; replay the flow.
4. Run Flutter's `meetsGuideline(textContrastGuideline)` and
   `androidTapTargetGuideline` in widget tests where practical.

## Customize for your project

Target level: WCAG 2.2 AA. Screen readers: VoiceOver and TalkBack.
