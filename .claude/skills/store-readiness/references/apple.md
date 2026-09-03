# Apple App Store checklist

Guideline numbers are from the App Store Review Guidelines, which has five
top-level sections: **1. Safety · 2. Performance · 3. Business · 4. Design ·
5. Legal**. Always cite the number — it's what App Review cites back.

Re-fetch the guidelines at audit time; numbering and wording do shift.

## The rejections that actually happen

### 2.1 — Incomplete submission
Placeholder text, empty websites, dead URLs, or a demo account that doesn't
work. Everything submitted must be the final version with working metadata.

**Check:** every URL in the listing resolves; no `example.com`, no `TODO`.

### 4.2 — Minimum functionality
"Not particularly useful, unique, or app-like." A thin wrapper around a
website, or an app whose whole value is a single static list, gets rejected.

**Check:** does the app do something a bookmark couldn't? Highest risk for
simple utility and content apps.

### 5.1.1(i) — Privacy policy
Required both as an App Store Connect metadata link **and** accessible inside
the app.

**Check:** URL reachable, non-geofenced, not a PDF, and reachable from a
Settings/About screen in-app.

### 5.1.1(ii) — Purpose strings
Every `NS*UsageDescription` must clearly and completely describe the *specific*
use. Boilerplate is rejected.

Bad: "This app requires photo access."
Good: "Choose a photo to set as a contact's picture. Photos stay on your device."

### 5.1.1(v) — Account deletion
If the app supports account creation, it must offer account deletion **from
inside the app**. Pointing users at an email address or a support page is not
sufficient.

### 4.8 — Login services
Offering Google/Facebook/other third-party login triggers a requirement to
also offer an equivalent option that limits data collection to name + email,
allows a private email, and doesn't track for ads without consent. Sign in
with Apple satisfies this.

Exceptions: apps using only their own auth, education/enterprise apps,
government-ID apps, or clients for a specific third-party service.

### 3.1.1 — In-app purchase
Unlocking features, content, subscriptions, or a "full version" must use IAP.
License keys, external payment links, or QR-code unlocks are rejected.

**Check:** any paywall, "upgrade", or "pro" path must route through
StoreKit — not a web checkout.

### 2.3 — Accurate metadata
Screenshots must show the actual app in use. Marketing frames with invented UI,
or screenshots from a different platform, get rejected.

### 2.5.1 — Private/undocumented APIs
Rare in Flutter, but native plugins can trip it.

## App Store Connect requirements (need a human)

These cannot be verified from a repo — mark **UNVERIFIED** and list them for
the developer:

- **App Privacy "nutrition label"** — the data-collection questionnaire. Must
  match what the app actually does; mismatches are a common post-review
  removal.
- **Age rating questionnaire**
- **Export compliance** — set `ITSAppUsesNonExemptEncryption` in Info.plist to
  avoid being asked every upload
- **Demo account** if any content sits behind login — App Review *will* reject
  without working credentials
- **App Review notes** explaining anything non-obvious
- **Screenshot sizes** for every required device class

## Privacy manifest

`ios/Runner/PrivacyInfo.xcprivacy` — required since May 2024 for apps using
required-reason APIs and for listed third-party SDKs. This fails at **upload**
(App Store Connect), not at review, so it blocks earlier than most issues.

Common Flutter triggers: `shared_preferences` (UserDefaults API),
`path_provider` (file timestamp APIs), any analytics or attribution SDK.
