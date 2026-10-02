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
round trip. CI needs **no secrets**, so it runs in full on a pull request
from a fork; a red CI on your PR is a real failure, not a missing token.

Read a gate's result from a file and check the exit code, rather than piping
it into `tail`: a pipe reports the *pipe's* status, so a failing run looks
green.

Three test tags exist, declared in `dart_test.yaml`:

- **`live`** starts a real OpenSSH server on loopback and connects to it. No
  network and no privileges needed, so these run locally where `sshd` exists
  and skip themselves where it does not. CI excludes them, because a hosted
  runner refusing to start `sshd` should not read as this app being broken.
- **`perf`** asserts timing, with budgets several times the measured cost so
  they catch a regression rather than a slow machine. They run by default;
  exclude with `--exclude-tags perf` if your machine is pathological.
- **`bench`** is the full-size benchmarks — minutes, not seconds. Skipped by
  default; run with `flutter test --run-skipped --tags bench`.

### Running the `live` tests

They need nothing of any maintainer's. The test starts its own `sshd` on a
loopback port, in a temporary directory, with a throwaway host key and a
throwaway account, and kills it afterwards. All it looks for is a binary at
`/usr/sbin/sshd`, and it skips itself where there is none — so on Windows,
run them from WSL or any Linux machine.

```sh
sudo apt install openssh-server    # Debian/Ubuntu — the daemon, not the client
sudo pacman -S openssh             # Arch
flutter test --tags live
```

Nothing listens on a public interface, and none of your own SSH configuration
is read or written.

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
`core/theme/tokens.dart`, the `ColorScheme`, and the ARB files. There is
deliberately **no code generation** in this project; models are written by
hand. Don't add `build_runner` without asking.

### Strings go in both languages

The app ships English and Nepali. A new user-visible string needs an entry in
**both** `lib/l10n/app_en.arb` **and** `lib/l10n/app_ne.arb` — same key, same
placeholders. `test/l10n_parity_test.dart` fails on a key that exists in one
and not the other, so a missed translation is a red build rather than a blank
label on someone's phone.

If you do not write Nepali, say so in the pull request and put the English
text in the `ne` entry; a maintainer will replace it. That is a better
outcome than a key that only exists in one file.

### Tests

A change in behaviour should come with a test that fails without it. The
house style is to name what broke rather than what the function does — the
existing tests carry the bug they pin in a comment, and that comment is the
most useful line in the file when the test fails two years later.

Tests that need a server use the `live` tag and the self-contained `sshd`
harness above; do not add a test that reaches the network.

## Commits and pull requests

Commit messages here explain *why*, not what — the diff already says what. The
existing log is the best guide to the house style; a subject line that names
the behaviour ("a host that imported without the key it names") beats one that
names the file.

Keep mechanical changes (a rename, a `dart fix`) in their own commit, separate
from logic.

**Commit the paths you touched.** `git commit -- <path>` rather than
`git add -A`, which sweeps in generated files, a stray `.env`, and whatever
else the working tree happened to be holding. The repository ignores the
obvious credential paths, but an allowlist you type beats a denylist someone
else maintained.

**Never commit a private key, a real host address, or anyone's contact
details** — not even as a test fixture. Keys that tests need are *generated at
test time*; see `test/ssh/fixtures/pasted_keys.dart` and reuse it. A checked-in
key trips GitHub's push protection, and a fixture nobody can tell apart from a
leaked key teaches people to click through that warning.

## The tooling in this repository, and what you can ignore

Everything here works with nothing but the Flutter SDK. The rest is optional:

| Path | What it is |
|---|---|
| `.mcp.json` | MCP servers for coding agents — `dart mcp-server`, which ships inside the Dart SDK, and `marionette_mcp`, which needs `dart pub global activate marionette_mcp`. Only an agent reads this file; it has no effect on a build. |
| `.claude/skills/` | Project-scoped skills for coding agents. Prose, loaded on demand. See `docs/agent-tooling.md`. |
| `tool/` | Release-side helpers: `make_installer.ps1` (Windows installer, needs Inno Setup), `make_dmg.sh` (macOS), `generate_icons.py`, `screenshot_job.dart` (store screenshots), `third_party_notices.dart` (regenerates `THIRD_PARTY_NOTICES.md`). None is needed to build or test the app. |
| `android/fastlane/`, `ios/fastlane/` | Store upload. Every credential comes from the environment, so these are inert without secrets you do not have. |

If you change a dependency, regenerate the notices file:

```sh
dart run tool/third_party_notices.dart
```

## Code of conduct

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — Contributor Covenant 2.1.

## Security

Do not open a public issue for a vulnerability. See [SECURITY.md](SECURITY.md).

## Licence

By contributing you agree that your contributions are licensed under the
[MIT Licence](LICENSE), the same terms as the rest of the project.
