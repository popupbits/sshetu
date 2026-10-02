<!--
Thanks for the change. PROJECT.md is the real guide; CONTRIBUTING.md has the
mechanics. Delete anything below that does not apply.
-->

## What this changes, and why

<!-- The diff already says what. Say why — the behaviour, the bug, the
     decision. A sentence naming what a user sees is worth more than a
     file list. -->

## How it was checked

- [ ] `dart format --output=none --set-exit-if-changed lib test`
- [ ] `flutter analyze` — zero errors, zero warnings
- [ ] `flutter test --exclude-tags live`
- [ ] **I ran the app and looked at what I changed**, on: <!-- platform -->

<!-- If you could not run it — no device, a platform you cannot build for —
     say so here and name what is therefore unverified. Silence reads as
     "I checked", and that is the one thing it must never mean. -->

## Checklist

- [ ] No new `import 'package:flutter/material.dart'` — `material_ui` instead
- [ ] New user-visible strings are in **both** `lib/l10n/app_en.arb` **and**
      `lib/l10n/app_ne.arb` (`test/l10n_parity_test.dart` enforces this)
- [ ] No hardcoded colours or sizes — tokens and the `ColorScheme`
- [ ] A test pins the behaviour, or there is a reason here why not
- [ ] No secrets, keys, personal addresses or real hostnames in the diff
