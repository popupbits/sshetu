---
name: app-store-optimization
description: Improve how an app is found and how many people install it after seeing it — App Store and Google Play listing metadata, keywords, title and subtitle, screenshots, icon, localisation, and A/B testing. Use when asked about ASO, app store optimization, store listing copy, keywords, discoverability, search ranking, conversion rate, install rate, screenshots or store creatives, or when writing or reviewing a title, subtitle, short or full description.
---

# App Store Optimization

Making a listing *perform*: found in search, and installed once seen.

**This is not the submission audit.** Whether a listing will be *accepted* is
the `store-readiness` skill. This one assumes it will be accepted and asks
whether it will work. Reach for that one before a first release; this one
after, and repeatedly.

## Design rule: verify the volatile parts

Character limits, ranking inputs and testing tools all change. **Anything with
a number in it must be re-checked before you report it** — never from memory,
never from the snapshot in `references/`.

| What | Source |
| --- | --- |
| Apple product page fields and limits | https://developer.apple.com/app-store/product-page/ |
| Apple search and keywords | https://developer.apple.com/app-store/search/ |
| Play store listing best practices | https://support.google.com/googleplay/android-developer/answer/13393723 |
| Play metadata policy | https://support.google.com/googleplay/android-developer/answer/9898842 |

If a fetch fails, say so and mark that item **UNVERIFIED**. Do not fall back on
a remembered character count.

## The asymmetry that drives everything

The two stores take opposite approaches, and advice that ignores this is worse
than no advice.

**Apple indexes a fixed set of fields.** App name, subtitle and a dedicated
**100-character keywords field** — comma-separated, invisible to users. The
description is **not** indexed, and promotional text does not affect ranking.
So the keyword field is a hard budget to spend deliberately, and the
description is pure persuasion.

**Google Play has no keyword field.** Play's ranking inputs are not publicly
documented, and its own guidance explicitly discourages keyword stuffing —
it asks for "a well-written, succinct description" in "everyday language, not
a list of keywords". So on Play you write for a human and let natural phrasing
carry the terms.

The practical consequence: **the same copy cannot serve both stores.** A
keyword-dense Play description reads as spam and is against guidance; an Apple
description written to rank wastes effort on a field nobody searches.

## What actually moves the numbers

In rough order of impact, and worth saying plainly because listing work often
goes to the wrong place:

1. **Icon** — visible in every search result, before any text is read.
2. **First two screenshots** — most people never scroll the gallery. They must
   carry the value proposition on their own, legibly at thumbnail size.
3. **Title / app name** — carries the strongest search weight on both stores
   and is the largest text in results.
4. **Subtitle (Apple) / short description (Play)** — the one line that converts
   a glance into a tap.
5. **Keywords field (Apple only)** — invisible, but the whole discovery budget.
6. **Ratings and review volume** — affects both ranking and conversion, and is
   the slowest to change.
7. **Full description** — matters least for discovery; still where a motivated
   reader decides.

## Procedure

1. **Scope it.** Which app, which stores, which locales. Check for `ios/` and
   `android/` — do not write App Store copy for an Android-only app.
2. **Verify limits** from the table above.
3. **Read what exists.** In this project the Play listing lives in the repo:
   `android/fastlane/metadata/android/<locale>/{title,short_description,full_description}.txt`.
   Apple metadata usually lives in App Store Connect — see
   `references/apple.md` before adding it to the repo.
4. **Audit per store** with `references/apple.md` and `references/play.md`.
5. **Propose concrete replacement copy**, not advice. A finding that says
   "the subtitle could be stronger" is not actionable; write the subtitle,
   with its character count.
6. **Say what to test.** Anything you cannot know from the outside — which of
   two icons converts better — is a test, not an opinion. See the testing
   section in each reference.

## Report format

```
## <App> — ASO review

### Now (n)
Changes to make in this pass. For each: the field, the current value, the
proposed value, the character count against the limit, and why.

### Test (n)
Changes worth A/B testing rather than assuming. State the hypothesis and the
metric that would settle it.

### Later (n)
Worth doing, not now. Usually creative work or localisation.

### Unverified (n)
Limits or behaviour that could not be checked. Never silently omit.
```

## Rules

- **Write the copy.** Every proposal includes the literal text and its length.
- **Count characters against the verified limit**, and show the count. A
  suggestion that overflows is not a suggestion.
- **One store at a time.** Never propose the same string for both.
- **Never invent metrics.** You cannot see install or impression data unless
  the user provides it. Say what you would look at rather than what it says.
- **Never copy a competitor's name into keywords.** Apple rejects it, and it
  is a trademark problem regardless of store.
- **Localisation is discovery, not translation.** A locale's listing should use
  the words people in that locale actually search, which is rarely a literal
  translation of the English one.
- **Screenshots must show the real app.** Invented UI is a rejection cause —
  `store-readiness` covers that; here it also means a mockup you cannot ship
  is not a proposal.
