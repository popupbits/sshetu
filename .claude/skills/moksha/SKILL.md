---
name: moksha
description: Generate App Store and Play Store screenshots, feature graphics and promo art for this app with moksha — device frames, backgrounds, headlines, and validation against each store's upload rules. Use when asked to make, refresh or fix store screenshots, listing images, feature graphics, promo banners or social cards, or when a store rejects an image for its dimensions, aspect ratio or transparency.
---

# Making store assets with moksha

[moksha](https://github.com/lohanidamodar/moksha) renders the finished store
images: a capture goes in, a framed screenshot with a headline comes out at
exactly the size the store demands.

It is not in this repo. Clone it beside the project and use its CLI — a
checkout, not a dependency, so this app never carries it.

## Never hand-place these images

Every dimension here is a hard rejection, and every one of them produces a
perfectly valid PNG that a store then refuses. Do not crop, resize or export
by hand, and do not upload a raw device capture:

- **Play:** the long side may be at most **twice** the short side. A phone
  screenshot at its own native 1080x2400 is 2.22:1 and gets refused.
- **Both stores:** **no alpha channel.** Play wants 24-bit PNG; Apple rejects
  transparency outright.
- **Apple:** dimensions must match a size App Store Connect accepts —
  1320x2868 for the required 6.9" iPhone, 2064x2752 for the 13" iPad.

moksha checks all three after rendering and exits non-zero, so a failure lands
here rather than at upload. Trust that exit code over your own arithmetic.

## The flow

**1. Capture raw screens.** This project already has the harness:

```sh
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=SCREENSHOT_LOCALE=en \
  -d <device>
```

Captures land in `build/screenshots/` as `NN_<scene>.png`. Capture on a device
matching the family you are targeting — a phone emulator for phone shots, a
tablet AVD for tablet shots, an iPad simulator for iPad shots. The raw size
does not need to match the store size; moksha scales into its own canvas.

**2. Ask moksha what it supports.** Do not guess ids:

```sh
cd ../moksha && npm ci
npm run render -- --schema
```

That prints every `assetType`, `sizeId`, `layout`, `phoneFrame`, background,
pattern and text anchor.

**3. Write a job file.** One entry per screenshot:

```json
{
  "assets": [
    {
      "assetType": "android-phone-screenshot",
      "layout": "hero-center",
      "background": { "type": "gradient", "id": "sunset-pink" },
      "textOverlays": [
        { "text": "Everything in one place", "anchor": "top-center",
          "fontSize": 0.055, "font": "Inter", "weight": 800 }
      ],
      "screenshot": "01_home.png",
      "filename": "01_home.png"
    }
  ]
}
```

Headline copy for this app lives in `screenshots/headlines.json`. Read it from
there rather than inventing new wording — it is the same copy the store
listing uses, and it is reviewed.

**4. Render.**

```sh
npm run render -- --job job.json --images <app>/build/screenshots --out <app>/out
```

**5. Look at the result.** Open at least one PNG. The failures the exit code
cannot see are visual: a headline colliding with the device, copy running off
the canvas, a screenshot framed in the wrong device family.

**6. Put them where the upload lanes read from.**

- Play — `android/fastlane/metadata/android/<locale>/images/<slot>/`
  (`phoneScreenshots`, `tenInchScreenshots`, …)
- App Store — `ios/fastlane/screenshots/<locale>/<family>/`, when the project
  targets iOS

## Fonts and scripts

`font` is a Google Fonts family name; moksha downloads and registers it.

**A font renders the scripts it has glyphs for and silently draws nothing for
the rest.** Latin families do not cover Devanagari, and the failure is a blank
or boxed caption in a valid file. For Nepali copy use `Noto Sans Devanagari`.
moksha warns when a family fails to register — read the output, do not just
check the exit code.

## Choosing layouts

`--schema` lists them. Vary them across a set rather than using one for every
screenshot; the first two are what most people ever see, so put the strongest
benefit there. The `app-store-optimization` skill covers what the copy should
say.

## Out of scope

App Store **preview videos**. moksha renders stills. Apple wants a 15-30 second
screen recording, which is a separate job.
