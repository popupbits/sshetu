---
name: mobile-ui-design
description: Design and review mobile app UI/UX — visual hierarchy, spacing and type scales, accent theming, touch targets, screen states, and motion. Use when building or revamping mobile screens, adding a theming/accent system, or when a mobile UI looks generic, cramped, inconsistent, or "unfinished".
---

# Mobile UI design

Mobile screens fail for boring, fixable reasons: everything is the same size,
nothing has room to breathe, colour is decoration instead of meaning, and the
happy path is the only state anyone built. Fix those four and a screen looks
designed. This skill is the checklist for doing that deliberately.

## Start by deciding the hierarchy

Before touching a widget, answer for the screen: **what is the one thing the
user came here to do?** That element gets the strongest treatment — largest
type, most saturated colour, or the only filled button. Everything else steps
down. A screen where three things shout has no hierarchy, and the user has to
read all of it to find any of it.

Rank every element into primary / secondary / tertiary, then give each rank a
consistent treatment across the whole app. If two elements are the same rank
they must look the same; if they look the same they had better be.

## Tokens, not magic numbers

Every spacing, radius, size and duration comes from a small named scale. The
scale is what makes unrelated screens feel like one app, and it is the single
highest-leverage change in a revamp.

**Spacing — 4pt scale.** `4, 8, 12, 16, 20, 24, 32, 40, 48`. Nothing else.
Screen gutters 16–20. Space between related items 8–12; between groups 24–32.
Whitespace is the cheapest way to make a UI look considered — when a screen
looks cramped the fix is almost always more space between *groups*, not less
content.

**Radius.** Pick 3: small 8 (chips, inputs), medium 12–14 (cards, buttons),
large 20–24 (sheets, modals). Nested corners: the inner radius should be
smaller than the outer, or the gap between them looks wrong.

**Type ramp.** 6 steps, each with a fixed weight and purpose:

| Role | Size | Weight | Use |
|---|---|---|---|
| Display | 28–32 | 700–800 | One per screen, at most |
| Title | 20–22 | 700 | Section and screen titles |
| Body | 15–16 | 400 | Paragraphs, message text |
| Label | 13–14 | 500–600 | Buttons, list titles, form labels |
| Caption | 12–13 | 400 | Metadata, timestamps, helper text |
| Micro | 11 | 500 | Badges, chips, counts |

Body text never goes below 15. Caption never below 12. Line height 1.3–1.5 for
anything over one line; tight leading on multi-line body text is the most
common "looks amateur" tell.

**Never more than 2 font families.** One for UI, optionally one mono for code
or IDs. Bundle them; a font fetched at runtime fails offline and blocks paint.

## Colour carries meaning, not decoration

Define colour as **roles**, never as literal values sprinkled through views:

- `accent` — the brand/primary. Interactive and selected states only.
- `surface` / `surfaceRaised` — page background, then cards and sheets.
- `textPrimary` / `textSecondary` / `textMuted` — three levels, no more.
- `success` / `warning` / `error` — status only. Never decorative.
- `divider` — one hairline colour at low opacity.

Rules that matter:

- **Accent is a scarce resource.** If everything is accent-coloured, nothing
  reads as tappable. Typically one accent element per viewport.
- **Never hardcode a colour in a view.** The moment a user can pick an accent,
  every hardcoded blue becomes a bug. Route everything through the theme.
- Derive tints from the accent (`accent.withValues(alpha: 0.10–0.20)`) rather
  than hand-picking a second colour — tints stay correct when the accent
  changes.
- Status colours must survive a colourblind user: pair every colour with an
  icon or text label. A green dot alone communicates nothing to ~8% of men.

**Dark mode is not inverted light mode.** Elevate with lighter surfaces, not
shadows (shadows are invisible on dark). Pure black `#000` is fine for OLED
page background, but cards should sit at `#1C1C1E`-ish so they separate.
Desaturate accents slightly in dark, or they vibrate against dark surfaces.

### Choosing an accent palette

Offer 6–10 curated options, not a colour wheel. Each must:
hit 4.5:1 contrast on both light and dark surfaces as text/icon colour; stay
distinguishable from the success/warning/error set; and look intentional at
low opacity as a tint. Show them as a row of swatches with the current one
checked — a live preview beats a hex code.

## Touch, not click

- **Minimum touch target 48×48dp**, even when the icon is 20dp. Pad it.
- **8dp minimum gap between targets**, or fat fingers hit the wrong one.
- **Thumb zone**: primary actions belong in the bottom third. Top corners are
  the hardest place to reach one-handed — put destructive or rare actions
  there, never the main action.
- Respect safe areas and the keyboard inset. A form field the keyboard covers
  is a broken form.
- Anything tappable must *look* tappable and give feedback on press (ripple,
  scale, or colour change). Text that navigates but looks like body copy is
  invisible.

## Every screen has four states

Build all four or the screen is unfinished:

1. **Loading** — skeletons over spinners for content that has a known shape.
   No full-screen spinner if part of the page is already known.
2. **Empty** — never a blank page. Say what goes here, why it's empty, and
   give the action that fills it. This is the screen that teaches the app.
3. **Error** — plain language, the cause, and a retry. Never a raw exception,
   never "Something went wrong" alone.
4. **Content** — the happy path.

Also handle: partial data, offline, and the very-long-string case. Every label
should survive a 40-character value without overflowing — use `maxLines` and
ellipsis, and test with the longest realistic content, not "Test".

## Motion

Motion explains where things came from. It is not garnish.

- 150–200ms for local feedback (press, toggle, ripple).
- 250–300ms for transitions (route push, sheet, expand).
- `easeOut` for entering, `easeIn` for exiting, `easeInOut` for moving.
- Over 400ms feels broken. Under 100ms isn't perceived.
- Animate what changed, not the whole screen.
- Respect the reduce-motion accessibility setting.

## Component conventions

**Buttons** — one filled primary per screen; outlined for secondary; text for
tertiary. Destructive is text-red until confirmed, never a big red button
sitting next to a safe one.

**Lists** — one line of primary text, at most two of supporting. Metadata in
Caption. Leading icon or avatar sized 36–44. If rows have more than three
pieces of information, it wants a card instead.

**Cards** — group related content, 12–16 padding, medium radius, hairline
border *or* a subtle shadow, not both. Cards inside cards is a smell.

**Sheets** — for focused sub-tasks. Grab handle at the top, large radius on
top corners only, explicit opaque background (many frameworks do not inherit
the theme here), and scroll-controlled so the keyboard doesn't cover fields.

**Forms** — label above or floating, never placeholder-as-label (it vanishes
when typing). Validate on blur, not on every keystroke. Errors go under the
field they belong to, in words that say how to fix it.

**Empty inputs with a cost** — anything that spends money, time or bandwidth
says the cost *before* the tap: "Download · 1.2 GB", not "Download".

## Accessibility is not optional

- 4.5:1 contrast for body text, 3:1 for large text and icons. Check the muted
  greys — they are almost always the failure.
- Support text scaling to 200% without clipping. Fixed-height rows containing
  text break first.
- Label every icon-only button for screen readers.
- Don't rely on colour alone to convey state.

## Review checklist

Run this against any screen before calling it done:

- [ ] One clear primary action, visually strongest
- [ ] All spacing from the scale; groups separated more than items
- [ ] Type from the ramp; body ≥15, line-height ≥1.3
- [ ] No hardcoded colours in views; accent used sparingly
- [ ] Touch targets ≥48dp with ≥8dp gaps
- [ ] Loading, empty, error states all built
- [ ] Long strings, dark mode, and 200% text all survive
- [ ] Motion 150–300ms, only on what changed
- [ ] Icon-only controls labelled

## Anti-patterns

- Everything bold, so nothing is emphasised.
- Centre-aligned body paragraphs (fine for a short empty-state line, bad for
  anything longer).
- More than 2 accent colours competing.
- Dividers between every row *and* cards *and* backgrounds — pick one grouping
  mechanism.
- Icons without labels in a bottom nav with more than 3 items.
- Dialogs for things a sheet or inline edit would do better.
- Copy that describes the implementation ("Sync failed: HTTP 429") instead of
  the user's situation ("Too many requests — try again in a minute").

See `references/flutter.md` for how to wire this up in Flutter specifically.
