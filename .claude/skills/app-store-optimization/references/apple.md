# App Store — ASO reference

Snapshot. **Verify every number** against
https://developer.apple.com/app-store/product-page/ before reporting it.

## Fields

| Field | Limit (verify) | Indexed for search | Editable without a new build |
| --- | --- | --- | --- |
| App name | 30 | **yes** | no |
| Subtitle | 30 | **yes** | no |
| Keywords | 100 total | **yes** | no |
| Promotional text | 170 | **no** | **yes** |
| Description | long | **no** | no |

Two consequences worth planning around:

- Name, subtitle, keywords and description are tied to a **version submission**.
  Getting them wrong means waiting for the next release, so they are worth more
  care than the fields you can change any time.
- **Promotional text is the exception** — it can be updated whenever, so it is
  the right home for a launch, a sale or a seasonal line. It does not rank, so
  never spend keywords there.

## The keywords field

Comma-separated, no space after the comma — a space costs a character and buys
nothing. Spaces are allowed *inside* a phrase.

```
property,house,real estate,rent
```

Do not include:

- Words already in the **app name or subtitle** — those are indexed already, so
  repeating them wastes the budget
- Plurals of a word you already have
- The word "app", or your category name
- Competitor or trademarked names — a rejection cause, not a clever trick
- Duplicates in any form

Apple combines terms, so `real,estate` can match "real estate" — splitting
compound phrases into their parts often buys more coverage than the phrase.

## Screenshots and previews

- The first two are what appear in search results. Assume the rest are never
  seen.
- They must show the **actual app**. Invented UI, or another platform's UI, is
  rejected.
- Legible at thumbnail size — that is the size most people judge them at.
- Required per device class; check the current list before promising a set.

## Testing

**Product Page Optimization** — A/B test icon, screenshots and previews against
the live page, shown to a share of eligible users, with results in App
Analytics. This is the honest way to settle a creative disagreement.

**Custom Product Pages** — additional pages with their own screenshots,
previews and promotional text, reachable by their own URL. For campaigns and
audiences, not for search.

## Metadata in the repository

This project keeps **Play** metadata in the repo, but not Apple's — Apple's
lives in App Store Connect by default.

You can add `ios/fastlane/metadata/<locale>/` (`name.txt`, `subtitle.txt`,
`keywords.txt`, `description.txt`, `promotional_text.txt`) so the copy is
reviewable in git. **Do so deliberately:** the release lane calls
`upload_to_app_store`, which uploads metadata by default — placeholder files in
the repo will overwrite a live listing. Either fill them in properly first, or
pass `skip_metadata: true` until you do.
