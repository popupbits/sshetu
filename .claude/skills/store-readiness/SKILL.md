---
name: store-readiness
description: Audit a Flutter app for Apple App Store and Google Play submission readiness, checking the repo against store review guidelines and producing a prioritised list of blockers and fixes. Use when asked whether an app is ready to submit, ready to ship, ready for review, or to check store compliance, listing completeness, rejection risk, App Store guidelines, Play policy, data safety, privacy manifest, or target API level. Also use before a first release or after a long gap between releases.
---

# Store readiness audit

Assess one app at a time against the current App Store Review Guidelines and
Google Play policies, then report what would block or risk a rejection.

## Design rule: verify the volatile parts

Store rules change on a schedule you do not control. **Anything with a date,
a version number, or a character limit must be re-verified at audit time** —
never reported from memory or from the snapshot in `references/`.

Fetch these before reporting any threshold:

| What | Source |
| --- | --- |
| Play target API level + deadline | https://developer.android.com/google/play/requirements/target-sdk |
| Play developer policies | https://support.google.com/googleplay/android-developer/answer/16933379 |
| Play Data safety form | https://support.google.com/googleplay/android-developer/answer/10787469 |
| App Store Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| Apple privacy manifest | https://developer.apple.com/documentation/bundleresources/privacy-manifest-files |

If a fetch fails, say so and mark that check **UNVERIFIED** rather than
falling back on remembered values.

## Procedure

1. **Scope it.** Confirm which app, and which stores it actually targets.
   Check for `ios/` and `android/` directories — do not audit iOS for an
   Android-only app.
2. **Verify current thresholds** from the table above.
3. **Run the repo audit** in `references/flutter-audit.md` — these are
   mechanical checks against files, not judgement calls.
4. **Walk the store checklists** in `references/apple.md` and
   `references/play.md`.
5. **Report** in the format below.

## Severity

Rank every finding. The point of the audit is to separate "this will be
rejected" from "this could be better".

- **BLOCKER** — submission will be rejected or the build won't upload.
  Cite the guideline number or policy name.
- **RISK** — a reviewer could reasonably reject this; commonly cited.
- **POLISH** — improves conversion or listing quality, not a rejection cause.
- **UNVERIFIED** — could not check (no network, no store access, needs a
  human decision). Never silently omit these.

## Report format

```
## <App> — store readiness

Targets: iOS / Android / both        Verified against guidelines as of <date>

### BLOCKERS (n)
- [Store] <finding> — <guideline/policy ref>
  Fix: <concrete action, with file path where applicable>

### RISKS (n)
...

### POLISH (n)
...

### UNVERIFIED (n)
- <what could not be checked and why>

### Verdict
<One paragraph: submit now, or fix N blockers first.>
```

## Rules

- **Never claim an app is ready** when there are UNVERIFIED items that could
  be blockers. Say what is unknown.
- **Cite specifics.** "Missing privacy policy" is weak; "Guideline 5.1.1(i)
  — no privacy policy URL in `fastlane/metadata/`, and none linked in-app"
  is actionable.
- **Prefer file evidence over inference.** If a check needs the Play Console
  or App Store Connect (content rating, data safety answers, export
  compliance), mark it UNVERIFIED and say what the human must confirm — do
  not guess from the repo.
- **Anything a human must decide** — age rating, data-collection answers,
  IAP model — is UNVERIFIED, not a pass.
