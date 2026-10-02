# App Store listing

`deliver` uploads every `.txt` here **verbatim**, so these files are the
listing — there is nowhere to leave a note inside one. Anything you type
becomes public copy.

## Limits that are hard rejections

| File | Limit | Notes |
|---|---|---|
| `name.txt` | 30 | the app name |
| `subtitle.txt` | 30 | left empty; a longer one is rejected outright |
| `keywords.txt` | 100 | comma-separated, **no spaces after commas** — they count |
| `promotional_text.txt` | 170 | editable without a new build, unlike the rest |
| `description.txt` | 4000 | only ~3 lines show before "more" |
| `release_notes.txt` | 4000 | required for every update after the first |

## Empty on purpose

`subtitle.txt`, `keywords.txt`, `promotional_text.txt` and `support_url.txt`
ship empty. Empty means "not set yet", which is honest; a plausible-looking
placeholder is worse, because it uploads.

**`support_url.txt` is a submission blocker.** Apple requires a working
`https://` Support URL and rejects a `mailto:`. Put up a page and
point this at it.

## Search works differently from Play

Play indexes the full description. Apple does **not** — only `name`,
`subtitle` and `keywords` carry search weight. Keyword-stuffing
`description.txt` does nothing here except make it worse to read. The
`app-store-optimization` skill covers the split.

## Language

This listing is English only, and that is a constraint rather than a
choice. Apple accepts a fixed list
of languages; it includes `hi`, `bn-BD`, `ur-PK` and nine Indian languages,
but no `ne`. A directory named for a language Apple does not know is rejected,
so beej does not create one.

## Review contact: not in this repository

`review_information/` holds `first_name.txt`, `last_name.txt`,
`email_address.txt`, `phone_number.txt`, `demo_user.txt` and
`demo_password.txt`. Four of them are a real person's details, and this
repository is public, so they are **git-ignored** with a `.example` beside
each one. Write the real files before `fastlane release`; see
`RELEASE_READINESS.md` § *App Store review contact*.

`deliver` does not fail on a missing one — it uploads with the field unset,
and App Store Connect then refuses the submission. Nothing warns you at
upload time, so this is a step of the release rather than a safety net.

`notes.txt` is tracked: it is review guidance and carries no personal data.

## Uploading

```sh
cd ios
bundle exec fastlane release      # builds, then upload_to_app_store
```

Metadata and screenshots come from `ios/fastlane/metadata/` and
`ios/fastlane/screenshots/` — the directories this file and the screenshot
workflow write to, so nothing needs assembling at release time.
