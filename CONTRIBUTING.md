# Contributing to SSHetu

Thanks for looking. Issues, fixes and features are all welcome.

**Read [PROJECT.md](PROJECT.md) first.** It is the real guide — architecture,
conventions, and the reasoning behind decisions that otherwise look arbitrary.
This file only covers the mechanics.

## Getting set up

```sh
flutter pub get
flutter run
```

The README has the per-platform prerequisites (Windows needs Visual Studio's
C++ **ATL** component; Linux needs a handful of `-dev` packages).

## The gates

CI runs exactly these three, and a pull request needs all of them green:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze                 # zero errors and zero warnings
flutter test --exclude-tags live
```

Run them before you push — they take under a minute together and save a
round trip.

Two test tags exist:

- **`live`** starts a real OpenSSH server on loopback and connects to it. No
  network and no privileges needed, so these run locally where `sshd` exists
  and skip themselves where it does not. CI excludes them, because a hosted
  runner refusing to start `sshd` should not read as this app being broken.
- **`perf`** asserts timing, with budgets several times the measured cost so
  they catch a regression rather than a slow machine. Exclude with
  `--exclude-tags perf` if your machine is pathological.

## Analysis is not proof

**Run the app and look at what you changed.** This is not a general principle;
it is what this stack does. Every one of these passes `flutter analyze` and
fails only at runtime:

- A malformed SQL migration is a valid Dart string until SQLite rejects it, and
  the app then dies on first launch.
- `go_router` silently drops route transitions under a `material_ui`
  `MaterialApp` — screens snap instead of animating.
- A theme falls back to defaults when a package resolves the *frozen* Material
  `Theme` instead of this one.

If you genuinely cannot run it — no device, a platform you cannot build for —
say so in the pull request and name what is therefore unverified. Silence
reads as "I checked", and that is the one thing it must never mean.

## The rule that will bite you

**Never import `package:flutter/material.dart`.** Import
`package:material_ui/material_ui.dart` instead.

Both define `ThemeData`, `TextTheme`, `Icon` and friends. They are different
types with the same names, so mixing them produces errors like *"the argument
type 'ThemeData' can't be assigned to the parameter type 'ThemeData'"*.
`test/no_frozen_material_test.dart` fails the build if any file under `lib/`
breaks this. Do not delete that test.

PROJECT.md §4 covers the consequences, including why `GoogleFonts.xTextTheme()`
is wrong here.

## Adding things

Extending the app usually means adding an entry to one of three registries
rather than editing shared code — which is what lets two features be added
without touching the same lines:

| Registry | Add to it when |
|---|---|
| `lib/core/bootstrap.dart` | you need async work before the first frame |
| `lib/core/router/routes.dart` + `router.dart` | you add a screen |
| `lib/features/settings/tiles.dart` | you add a settings row |

Also: no hardcoded colours, sizes or strings — they come from
`core/theme/tokens.dart`, the `ColorScheme`, and `lib/l10n/app_en.arb`. There
is deliberately **no code generation** in this project; models are written by
hand. Don't add `build_runner` without asking.

## Commits and pull requests

Commit messages here explain *why*, not what — the diff already says what. The
existing log is the best guide to the house style; a subject line that names
the behaviour ("a host that imported without the key it names") beats one that
names the file.

Keep mechanical changes (a rename, a `dart fix`) in their own commit, separate
from logic.

## Security

Do not open a public issue for a vulnerability. See [SECURITY.md](SECURITY.md).

## Licence

By contributing you agree that your contributions are licensed under the
[MIT Licence](LICENSE), the same terms as the rest of the project.
