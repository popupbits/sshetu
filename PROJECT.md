# SSHetu — project guide

SSH client and server manager for every device.

One guide for humans and agents alike. `CLAUDE.md` and `AGENTS.md` point here.

## 1. Scope

**In scope:** features, fixes and refactors within the structure below, with
tests and localized strings.

**Out of scope unless explicitly asked:**

- Publishing, deploying, signing, or uploading builds
- Touching secrets, keystores, `key.properties`, `.env.android`, or API keys
- Large unrelated refactors, or an architecture rewrite
- New packages that duplicate something the project already does
- Committing or pushing

## 2. Working here

**Before changing anything** — read the files you are about to touch, follow
what is already there, and prefer a small focused edit to a broad rewrite. Ask
only when the task is genuinely ambiguous and guessing would be expensive.

**While changing it** — preserve edits already in the working tree. Keep
mechanical changes (a rename, a `dart fix`) in a separate commit from logic.
Use the project's established way of doing a thing rather than inventing a
second one.

**After changing it** — **run the app on a real device or emulator with
`flutter run` and look at what you changed.** Analyzing and testing is not
finishing; see §8. Then say what changed and which files matter, state what you
could *not* verify as plainly as what you could, and never report a command as
passing unless you ran it and saw it pass.

## 3. Stack

| Concern | Choice |
|---|---|
| Material | `package:material_ui` — **not** `package:flutter/material.dart` |
| State | Riverpod 3, no code generation |
| Routing | `go_router` with a `StatefulShellRoute` |
| Localization | `flutter gen-l10n` from `lib/l10n/*.arb` (en) |
| Icons | `picons` (`PiconsRegular.*`) |
| Backend | Appwrite |
| Local storage | `sqflite` with numbered SQL migrations |
| Theme | tokens owned by this project |
| Platforms | Android iOS desktop |

**Dependencies.** Prefer what is already here. Add with
`flutter pub add <package>` rather than hand-editing constraints. Do not add a
package for a few lines of helper logic.

**No code generation.** No `build_runner`, `freezed`, `json_serializable`, or
generated Riverpod providers. Models are written by hand. This is deliberate —
do not introduce a codegen step without asking.

## 4. The one rule that will bite you

**Never import `package:flutter/material.dart`.** Import
`package:material_ui/material_ui.dart` instead.

Both libraries define `ThemeData`, `TextTheme`, `Icon` and friends. They are
different types with the same names, so mixing them produces errors like *"the
argument type 'ThemeData' can't be assigned to the parameter type
'ThemeData'"*. `test/no_frozen_material_test.dart` fails the build if any file
under `lib/` breaks this rule.

Third-party packages that still use frozen Material (`picons`, `google_fonts`, `go_router`)
are fine — `MaterialUiCompatibilityBridge`, wired into `MaterialApp.builder` in
`core/app.dart`, bridges them.

Three consequences worth knowing:

- Use `googleFontsTextTheme(base, GoogleFonts.inter)` from
  `core/theme/google_fonts_text_theme.dart`, never `GoogleFonts.interTextTheme()` —
  the latter returns a frozen `TextTheme` that `material_ui`'s `ThemeData`
  rejects.
- Localization delegates come from `GlobalMaterialLocalizations.delegates`
  (exported by `material_ui`), covering Flutter, Material and Cupertino. This
  app neither declares nor imports `flutter_localizations`. That package has
  *not* been decoupled — only the Material and Cupertino localizations moved
  out. `GlobalWidgetsLocalizations` stayed with the widgets layer, so
  `material_ui` depends on it for you.
- go_router picks its page type by looking for a *frozen* `MaterialApp`
  ancestor. Routes declared with plain `builder:` silently lose their
  transitions. This project's routes are fine; keep new ones consistent, and
  reach for an explicit `pageBuilder` returning a `MaterialPage` if a
  transition ever goes missing.

The `material-ui` skill in `.claude/skills/` covers this in full.

## 5. Layout

```
lib/
  main.dart                  entry: bootstrap, then runApp
  core/
    app.dart                 root MaterialApp — theme, locale, bridge
    bootstrap.dart           ordered async init  ← REGISTRY
    config/app_config.dart   compile-time config and --dart-define overrides
    error/                   error capture, the on-device log
    router/
      routes.dart            every path constant  ← REGISTRY
      navigation.dart        context.goTo / pushTo / back
      router.dart            the router itself
    settings/                AppSettings model + persisted controller
    theme/                   tokens, accent palette, ThemeData, font bridge
    ui/                      shared widgets: views, async_view, feedback
    util/                    responsive, launcher
    db/                      database + numbered migrations
    appwrite/                client, failures, base repository
  l10n/                      app_en.arb, app_ne.arb, generated output
  features/
    <feature>/               one folder per feature
    settings/
      tiles.dart             settings rows  ← REGISTRY
      diagnostics_screen.dart  the captured error log
```

### The three registries

Extending the app means adding an entry to one of these, not editing shared
code. That is what lets two features be added without touching the same lines.

| Registry | Add to it when |
|---|---|
| `core/bootstrap.dart` | you need async work before the first frame, or a resource handed to a provider |
| `core/router/routes.dart` + `router.dart` | you add a screen |
| `features/settings/tiles.dart` | you add a settings row |

## 6. Conventions

- **No hardcoded values.** Spacing, radii, durations and border widths come
  from `core/theme/tokens.dart`. Colours come from `Theme.of(context).colorScheme`.
- **No hardcoded strings.** Everything user-visible goes through
  `AppLocalizations.of(context)`, with entries in **both** `app_en.arb` and
  `app_ne.arb`.
- **One widget per file** unless a widget is private to its parent and used
  nowhere else.
- **Immutable models** with `copyWith`. Use an explicit `clearX` flag to set a
  nullable field back to null.
- **Provider naming:** `xRepositoryProvider`, `xControllerProvider` (async
  actions), `xProvider.family` (keyed lookup), `xNotifierProvider` (mutable
  state).
- Prefer `ref.watch(p.select((s) => s.field))` over watching a whole object
  when a widget needs one field.
- Handle loading, error and empty states. `core/ui/` has `AsyncView`,
  `EmptyView`, `ErrorView` so you do not rewrite them per screen.

## 7. Responsive layout

One codebase adapts by **width**, never by operating system. Platform checks
are for platform capabilities only.

`core/util/responsive.dart` owns this. Do not scatter raw width checks.

| Class | Width | Shape |
|---|---|---|
| `compact` | < 600 | one column, bottom navigation |
| `medium` | 600–1023 | two columns, navigation rail |
| `expanded` | ≥ 1024 | multi-column, content capped at 1280 |

- `context.isCompact / isMedium / isExpanded / useRail`
- `context.gridColumns()` for card grids
- `ContentWidth` caps text-shaped content — never stretch a form or prose
  edge-to-edge on a desktop window
- The shell owns navigation; a destination renders body content only

**Proof obligation:** any new or meaningfully changed screen is checked at a
phone width *and* a desktop width. When the adaptive behaviour matters, the
widget test covers both.

## 8. Testing

- Tests live in `test/`, mirroring `lib/`.
- `test/no_frozen_material_test.dart` — guards the rule in §4. Do not delete it.
- `test/database_test.dart` — applies every migration to an in-memory database.
  Malformed SQL is a valid Dart string right up until SQLite rejects it at
  first launch, so this is the only thing standing between a bad migration and
  a device.
- `test/app_smoke_test.dart` — the app builds, routes and renders. Shallow on
  purpose: it exists to fail loudly when startup breaks.
- `test/error_logger_test.dart` — deduplication, the size cap, and surviving a
  corrupt stored log.

`.github/workflows/ci.yml` runs `flutter analyze` and `flutter test` on every
push and pull request. That is what makes the guarantees above binding rather
than aspirational — a guard nobody runs is not a guard. Releasing stays
separate and manual.

Write a test for logic worth trusting: parsing, formatting, state transitions,
anything with a branch. Do not chase coverage on generated or trivial code.

### Analysis is not proof — run it

**Always run the app on a connected device or emulator before calling a change
done.** A green `flutter analyze` and a green `flutter test` say the code is
well-formed, not that it works.

This is not a general principle; it is what this stack does. Every one of these
passes analysis and fails only at runtime:

- A malformed SQL migration is a perfectly valid Dart string until SQLite
  rejects it, and the app then dies on first launch.
- go_router silently drops route transitions under a `material_ui`
  `MaterialApp` — screens snap instead of animating (§4).
- A theme falls back to defaults when a package resolves the frozen Material
  `Theme` instead of this one.
- A plugin that is fine on the host fails on the device: a permission, a
  missing platform channel, an unavailable service.

```sh
flutter devices          # what is actually connected
flutter run              # then exercise the screen you changed
```

Prefer the Dart MCP's `launch_app` plus `get_runtime_errors` over watching a
terminal — reading the app's real errors is the point.
No device to hand? `android emulator list`, then
`android emulator start <avd>`.

**If you genuinely cannot run it** — no device, no emulator, a platform you
cannot build for — say so explicitly and name what is therefore unverified.
Silence reads as "I checked", and that is the one thing it must never mean.

## 9. When something goes wrong at runtime

`core/error/` captures errors the app cannot otherwise tell you about. All
three routes out of a Flutter app are covered: `FlutterError.onError` for build
and layout failures, `PlatformDispatcher.onError` for uncaught async errors,
and a guarded zone around `main` for everything else.

This matters more here than in an ordinary project. The two worst failure modes
in a `material_ui` app — a lost route transition, a theme silently falling back
— pass `flutter analyze` and appear only on a device you do not have.

- Records are deduplicated by a stable fingerprint and capped at 50, so a crash
  loop costs one row rather than filling the device.
- Everything stays on the device. Settings → Diagnostics shows the log, and
  sharing it is the user's deliberate act.
- `ErrorLogger.instance.record(error, stackTrace)` (or
  `ref.read(errorLoggerProvider)`) records something you caught yourself.
- Catching an error and showing a message is still right. Record it as well
  when you would want to know it happened.
- `core/error/appwrite_error_sink.dart` can forward errors to an `error_logs`
  table. It is generated but **not wired up**: stack traces carry more about a
  user's session than they appear to, so turning it on belongs in your privacy
  policy before it belongs in `main.dart`.

## 10. Commands

```sh
flutter pub get
flutter analyze          # zero errors and zero warnings before you call it done
flutter test
flutter run              # on a device; see §8
flutter pub add <pkg>
```

Store screenshots:

```sh
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d <device>
```

Output lands in `build/screenshots/`. Edit the nav steps in
`integration_test/screenshot_test.dart` as the app grows; the helper fails the
run if it captures nothing, because a green run with an empty store listing is
indistinguishable from a working one.

**Headline copy** lives in `screenshots/headlines.json`, in one file because
both stores read it. Two manual workflows do the rest on a runner and commit
the result — they never run on push, because they rewrite the repository.

| Workflow | Runner | Families |
|---|---|---|
| **Screenshots (Android)** | `ubuntu-latest` | phone, 10" tablet |
| **Screenshots (iOS)** | `macos-latest` | iPhone 6.9", iPad 13" |

Each captures on an emulator or simulator matching the family, turns
`headlines.json` into a job with `tool/screenshot_job.dart`, renders it with
[moksha](https://github.com/lohanidamodar/moksha), and **opens a pull request**
— the diff is the review, and no workflow needs write access to a protected
branch.

moksha validates every image against the store's upload rules and fails the
job on a violation, so the three rejections that produce a perfectly valid PNG
— an alpha channel, a Play aspect ratio over 2:1, a dimension Apple does not
recognise — surface in CI rather than at upload. `screenshots/README.md` has
the rest.

Release builds are run only when explicitly asked:

```sh
flutter build apk --release
flutter build appbundle --release
```

## 11. Common tasks

### Add a screen

1. `lib/features/<name>/<name>_screen.dart` — body content, not a `Scaffold`,
   if it is a shell destination
2. Add its path to `core/router/routes.dart`
3. Register it in `core/router/router.dart`
4. Add its strings to **both** `.arb` files

### Add a string

Add the key to `lib/l10n/app_en.arb` **and** `lib/l10n/app_ne.arb`, then rebuild.
`generate: true` in `pubspec.yaml` regenerates `AppLocalizations` on the next
`flutter run`/`build`; `flutter gen-l10n` does it on demand.

### Add a database migration

1. Write `lib/core/db/migrations/vN_<name>.sql`
2. Append it to `migrations` in `lib/core/db/migrations/migrations.dart`
3. Bump `kSchemaVersion`

Migrations run in order on open, each applied at most once. `flutter test`
proves they apply — run it.

### Release

```sh
cd android
bundle install                    # once
bundle exec fastlane internal     # or beta / release
```

Requires `.env.android` (gitignored) with `APP_IDENTIFIER`, the keystore values,
and a path to the Play service-account JSON.

Release notes come from `android/fastlane/metadata/android/<locale>/changelogs/`.
`supply` uploads the file whose name matches the build's versionCode and falls
back to `default.txt`, so an unedited `default.txt` becomes your public "What's
new". Write the real notes before you ship.

For iOS:

```sh
cd ios
bundle install
bundle exec fastlane beta         # TestFlight, or `release` for the App Store
```

The App Store listing is in the repo too, under `ios/fastlane/metadata/`, and
`deliver` uploads every `.txt` there **verbatim** — there is nowhere to leave a
note inside one. Read `ios/fastlane/metadata/README.md` before editing: the
character limits are hard rejections, and `support_url.txt` ships empty because
Apple requires an `https://` URL and rejects a `mailto:`.

The two stores do not take the same languages. Play accepts Nepali; App Store
Connect does not — its fixed list has `hi`, `bn-BD` and `ur-PK` but no `ne`. So
the Play listing is localised and the App Store one is English only, and that
asymmetry is deliberate rather than an omission.

CI does the same thing from `.github/workflows/android-release.yml`, which is
manual-dispatch only. That workflow is **self-contained** — it does not call a
reusable workflow elsewhere, so it runs for anyone who can read this repo, and
it cannot break because something in another repository changed. It needs six
repository secrets; the file lists them at the top.

Before a release, check: app name, application id, version name and code, icon,
permissions, signing, privacy-policy URL reachable, store listing text,
screenshots. Two skills in `.claude/skills/` cover this: `store-readiness`
audits whether the submission will be **accepted**, and
`app-store-optimization` works on whether the listing will be **found and
installed**. The Play listing itself is in the repo under
`android/fastlane/metadata/`, so listing copy is reviewed like code.

**Never print, rewrite or commit signing credentials.**

## 12. Appwrite

- Endpoint, project and database ids live in `core/config/app_config.dart` and
  are overridable with `--dart-define`.
- `core/appwrite/client.dart` wraps the SDK clients. The 1.8+ data API is
  `TablesDB`, so collection ids are passed as `tableId` and document ids as
  `rowId`.
- `core/appwrite/base_repository.dart` gives `list`, `get`, `create`,
  `update`, `delete` over one table.
- `core/appwrite/failures.dart` maps SDK errors to typed failures. Wrap every
  SDK call in `runAppwrite`. UI surfaces failures as a snackbar with a retry.
- Auth state is derived from `account.get()`; the SDK owns the session cookie,
  so nothing persists it by hand.

## 13. Tooling — use it when it is there

Prefer a real tool over shelling out by hand. Each of these is optional: check
once, use it if present, fall back quietly if not. Never make a task fail
because a tool is missing.

### Dart / Flutter MCP

`.mcp.json` declares it, and it ships **inside the Dart SDK** (`dart
mcp-server`) so there is nothing to install. One server covers both languages:

- `analyze_files`, `run_tests`, `dart_fix`, `dart_format`
- `launch_app`, `hot_reload`, `hot_restart`, `stop_app`, `list_devices`
- `get_runtime_errors`, `get_app_logs`, `widget_inspector`
- `pub`, `pub_dev_search`, `read_package_uris`

Reach for it before `flutter run` in a terminal: it is the difference between
reasoning about this app and actually running it. **This matters more here than
usual** — the two worst `material_ui` failures (§4) pass `flutter analyze` and
appear only at runtime, so reading real runtime errors is how you catch them.

### Android CLI

Google's `android` command, in the SDK's `cmdline-tools/latest/bin`. Newer and
much broader than `adb`; if it is on PATH, prefer it.

| Command | Use |
|---|---|
| `android info` | SDK path, connected devices, config — start here when something is off |
| `android emulator list` / `start <avd>` | boot a device without opening Android Studio |
| `android screen capture` | device screenshot straight to PNG (no `adb shell screencap` + `pull` dance) |
| `android layout` | the running app's layout tree, for debugging what actually rendered |
| `android docs search "..."` | official Android documentation, rather than guessing |
| `android sdk install/list` | fix a missing platform or build-tools package |
| `android install <apk>` | incremental install, faster than `adb install` |

`flutter run` and `flutter build` stay the build path for this project — the
Android CLI complements them for device, emulator, SDK and inspection work.

Add `--no-metrics` if you would rather it not report usage.

### Skills

`.claude/skills/` holds skills scoped to this project; they load on demand when
a task matches. See `docs/agent-tooling.md`.

## Before you call it done

- [ ] The change is scoped to what was asked
- [ ] `flutter analyze` — zero errors, zero warnings
- [ ] `flutter test` passes; new logic has tests
- [ ] **Ran on a device or emulator and exercised the change** — or said plainly
      that you could not, and what is unverified as a result
- [ ] Changed screens checked at compact *and* expanded widths
- [ ] Loading, error and empty states handled
- [ ] New strings in **both** `.arb` files
- [ ] No `package:flutter/material.dart` import
- [ ] No hardcoded colours, sizes or strings
- [ ] No unrelated refactor, no unnecessary dependency
- [ ] No secret, keystore or production config touched
- [ ] What you could not verify is stated plainly

## Anti-patterns

- `import 'package:flutter/material.dart'` — see §4
- `GoogleFonts.xTextTheme()` — see §4
- Raw `Color(0xFF…)` in a widget — use the colour scheme
- Literal strings in the UI — use the ARB files
- `withOpacity` — deprecated; use `withValues(alpha: x)`
- Raw width checks in feature widgets — use `core/util/responsive.dart`
- Editing `lib/l10n/app_localizations*.dart` — it is generated
