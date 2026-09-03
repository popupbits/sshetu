# Google Play — ASO reference

Snapshot. **Verify every number** against
https://support.google.com/googleplay/android-developer/answer/13393723
before reporting it.

## Fields

| Field | Limit (verify) | Notes |
| --- | --- | --- |
| App title | 30 | The strongest single signal, and the largest text in results |
| Short description | 80 | The line shown before "read more"; the main conversion lever |
| Full description | 4000 | Where a motivated reader decides |

There is **no keywords field.** Play's ranking inputs are not publicly
documented, and its guidance is explicit that a description should be "a
well-written, succinct description" in "everyday language, not a list of
keywords". Listing terms "unrelated to your app" is called out as something not
to do.

So: write for a person. Natural phrasing carries the terms it needs, and
stuffing is both against guidance and a bad read.

## Title

- Your product name, plus a few words of what it does, if it fits.
- Do not put "Free", "Best", "#1", a price, or a store badge in it — those are
  a metadata-policy problem, not just bad taste.
- Emojis and decorative symbols are a policy problem too.

## Short description

The 80 characters that do the most work in the whole listing. One clear
sentence about what the app does for the reader. Not a tagline, not a slogan.

## Full description

- The first two lines are all most people see. Lead.
- Short paragraphs and plain sentences beat a bulleted feature dump.
- Repeat the core term naturally a couple of times. Do not enumerate variants.

## Screenshots

- At least two phone screenshots, or Play will not publish at all.
- Cover the device types you support, in the orientations you support.
- Minimal text; a tagline only when it genuinely adds something.
- Show the real app.

## Testing and targeting

**Store listing experiments** — A/B test the icon, screenshots, short and full
description against live traffic. Use this instead of arguing about creative.

**Custom store listings** — separate listings for specific audiences (by
country, install state, or campaign). For targeting, not for search.

## Metadata in the repository

This project keeps the Play listing in git:

```
android/fastlane/metadata/android/<locale>/
  title.txt
  short_description.txt
  full_description.txt
  video.txt
```

Edit those files, not the Console — the Console will be overwritten on the next
`fastlane release`, which runs with `upload_metadata: true`.

A locale directory exists only for locales the app actually ships. Adding one
means committing to a listing in that language: a half-translated listing reads
worse than an English one.
