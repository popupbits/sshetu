# Store screenshots

Every store listing image is built by a GitHub workflow and arrives as a pull
request. The copy and styling live in `headlines.json`, in one file, because
every store and every device family reads the same one.

## How it works

| Step | What runs |
|---|---|
| Capture | `integration_test/screenshot_test.dart`, on an emulator or simulator matching the device family |
| Job | `tool/screenshot_job.dart` turns `headlines.json` into a moksha job |
| Render | [moksha](https://github.com/lohanidamodar/moksha) — device frame, background, headline, at the exact store size |
| Review | the workflow opens a PR; the diff is the review |

One renderer for every store, so the listings look like the same app.

## The workflows

**Screenshots (Android)** on Ubuntu, **Screenshots (iOS)** on macOS. Each takes
a locale and which device families to regenerate:

| Family | Captured on | Output |
|---|---|---|
| Android phone | `pixel_6` emulator | 1080x1920 |
| Android 10" tablet | tablet AVD | 1600x2560 |
| iPhone 6.9" | iPhone 17 Pro Max simulator | 1320x2868 |
| iPad 13" | iPad Pro 13" simulator | 2064x2752 |

Neither runs on push — they rewrite listing images, so they are manual.

## Changing the copy

Edit `headlines.json`. One entry per scene:

```json
{ "id": "home", "headline": { "en-US": "Everything in one place" } }
```

Scene ids match the capture names the integration test writes. Add a screen
there and add it here, or the capture is skipped with a warning.

`background`, `layouts` and font names must be ones moksha knows:

```sh
cd ../moksha && npm ci && npm run render -- --schema
```

`layouts` is a list and is cycled across the screenshots, so a set has some
rhythm instead of reading like a contact sheet.

These are store copy, not UI strings: write the benefit, not the feature name.
The `app-store-optimization` skill covers what belongs here — most people never
scroll past the first two.

## Three rules that reject a perfectly good image

moksha checks all of these after rendering and fails the job, so a violation
lands in CI rather than at upload:

- **No alpha channel.** Play wants 24-bit PNG; Apple rejects transparency.
- **Play aspect ratio.** The long side may be at most twice the short side — a
  phone capture at its own native 1080x2400 is 2.22:1 and is refused.
- **Apple dimensions.** Must match a size App Store Connect accepts.

## Where the output goes

- Play — `android/fastlane/metadata/android/<locale>/images/<slot>/`
- App Store — `ios/fastlane/screenshots/<locale>/<family>/`

Both are the directories `supply` and `deliver` upload from, so
a merged PR is already in the release path.

## Doing it by hand

The `moksha` skill in `.claude/skills/` walks an agent through the same steps
locally — capture, build a job, render, look at the result.
