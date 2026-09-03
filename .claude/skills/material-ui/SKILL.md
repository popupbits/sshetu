---
name: material-ui
description: Work with package:material_ui, the Material library decoupled from the Flutter SDK. Use when an app imports material_ui, when a "ThemeData can't be assigned to ThemeData" or "TextTheme" type error appears, when route transitions or theming silently break after a Flutter or dependency upgrade, when adding a package that still imports package:flutter/material.dart, or when migrating an app off frozen Material.
---

# material_ui

Flutter 3.44 moved Material out of the SDK. `package:flutter/material.dart`
still exists but is **frozen**; `package:material_ui/material_ui.dart` is the
live library. This skill is about the seam between them.

## The one thing to understand

Both libraries declare `ThemeData`, `TextTheme`, `MaterialApp`, `MaterialPage`,
`Icon` and dozens more **under the same names, as unrelated types**. No shared
base class, no implicit conversion. Mixing them produces:

```
The argument type 'ThemeData' can't be assigned to the parameter type 'ThemeData'
```

which is among the least helpful messages the analyzer emits, because the two
names are identical in the error text.

**Rule: nothing under `lib/` imports `package:flutter/material.dart`.** There is
no lint for a banned import, so enforce it with a test that greps `lib/` — see
"Guard test" below. `material_ui` re-exports `package:flutter/widgets.dart`, so
widgets-layer types (`BuildContext`, `Widget`, `IconData`, `TextStyle`) are
shared and need no bridging.

## Version trap: 0.0.1 is a shim

| Version | What it actually is |
|---|---|
| `0.0.1` | A single file: `export 'package:flutter/material.dart';`. A rename, not a migration. Code on it is still frozen Material. |
| `1.x` | The real forked library. |

**A pubspec saying `material_ui` tells you nothing** — check the version before
concluding an app has migrated. An app pinned to `^0.0.1` whose files all import
`material_ui` has not migrated at all.

## Third-party packages that still use frozen Material

Common ones: `google_fonts`, `go_router`, `picons` / `phosphor_flutter`,
`flutter_markdown_plus`, `nepali_date_picker`.

They work, but need the bridge, wired once at the root:

```dart
MaterialApp(
  // Deprecated upstream on purpose — it is a migration utility, and stays
  // necessary for as long as dependencies keep importing frozen Material.
  // ignore: deprecated_member_use
  builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
)
```

Without it those widgets throw at runtime looking for a legacy `Theme` or
`MaterialLocalizations`. Compose with any existing `builder`; do not replace it.

Your own files still must not import frozen Material — the bridge is for code
you do not control.

## The failures that pass `flutter analyze`

These are the expensive ones. They compile, they lint clean, and they are wrong.

### go_router loses every route transition

go_router picks its page type with
`findAncestorWidgetOfExactType<MaterialApp>()` against the **frozen** type. Under
a `material_ui` `MaterialApp` it finds nothing and silently falls back to
`NoTransitionPage`. Screens snap instead of animating.

Fix: give routes an explicit `pageBuilder` returning a `material_ui`
`MaterialPage`, mirroring what go_router itself sets:

```dart
Page<void> _page(GoRouterState state, Widget child) => MaterialPage<void>(
  key: state.pageKey,
  name: state.name ?? state.path,
  child: child,
);
```

Verify by test rather than by eye: mid-navigation, both the outgoing and
incoming screens should be on-stage. With `NoTransitionPage` only the incoming
one is.

### GoogleFonts.\<font\>TextTheme() will not compile

`GoogleFonts.interTextTheme()` returns a **frozen** `TextTheme`, which
`material_ui`'s `ThemeData` rejects. This one is at least loud.

`GoogleFonts.inter(...)` is fine — it returns `TextStyle`, which lives in
`painting/` and is shared. So build the theme slot by slot:

```dart
TextTheme googleFontsTextTheme(
  TextTheme base,
  TextStyle Function({TextStyle? textStyle}) font,
) => TextTheme(
  displayLarge: font(textStyle: base.displayLarge),
  // … all 15 slots
);
```

That is exactly what `interTextTheme()` does internally, retyped.

**While you are in there:** check whether the font actually reaches the theme.
A common pattern is `GoogleFonts.xTextTheme(base)` followed by overriding every
slot on top of it — in which case the font never applied and nobody noticed.
Preserve the shipping appearance rather than silently restyling; restoring the
intended font is a design decision, not a migration one.

### flutter_markdown_plus renders near-black headings

`MarkdownWidget` always computes `MarkdownStyleSheet.fromTheme(Theme.of(context))`
internally and merges yours over it. With no frozen `Theme` ancestor that base
becomes `ThemeData.fallback()`, so headings resolve to `#1D1B20`. Supply every
field explicitly, or wrap the subtree in the bridge.

## Localization

Localizations were **not** decoupled. `flutter_localizations` is still an
SDK-only package; what moved is the *Material and Cupertino* localizations,
into `material_ui` and `cupertino_ui`. `GlobalWidgetsLocalizations` stayed
behind with the widgets layer, and both new packages depend on
`flutter_localizations` to get it.

So an app neither declares nor imports it, and takes all three delegate sets
from one place:

```dart
localizationsDelegates: const [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates, // from material_ui
],
```

Declaring `flutter_localizations` yourself invites using its **frozen**
`GlobalMaterialLocalizations`, which is a different class from material_ui's.

## Migrating an app

1. `dart fix --apply --code=migrate_design_widgets` — material_ui ships this
   data-driven fix. Otherwise replace the imports by hand.
2. Bump `material_ui` to `^1.0.1`; add `cupertino_ui` only if you name a
   Cupertino type directly.
3. Drop `flutter_localizations` from the pubspec and use material_ui's delegates.
4. Raise the SDK floor to `^3.12.0` / Flutter `>=3.44.0`.
5. Wire the bridge.
6. Fix the silent failures above — by inspection, not by chasing errors.
7. Add the guard test.

Watch for a side effect of step 4: raising the language version can activate
lints that were previously inapplicable (`prefer_initializing_formals` starts
firing on private-field initializing formals). That is unrelated to Material —
keep it in its own commit.

Beware `dart fix` volunteering `flutter_localizations: any` back into the
pubspec, because generated gen-l10n output imports it directly. That reverses
step 3; drop the hunk.

## Guard test

```dart
test('no file under lib/ imports package:flutter/material.dart', () {
  final offenders = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains('app_localizations')) continue; // generated
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('package:flutter/material.dart') &&
          lines[i].trimLeft().startsWith(RegExp(r'import|export'))) {
        offenders.add('${entity.path}:${i + 1}');
      }
    }
  }
  expect(offenders, isEmpty);
});
```

Verify it in both directions: it should pass now, and fail with the offending
path when a frozen import is planted.

## Checklist

- [ ] `material_ui` is `^1.x`, not `^0.0.1`
- [ ] Nothing under `lib/` imports `package:flutter/material.dart`
- [ ] Guard test present and verified to fail when it should
- [ ] `MaterialUiCompatibilityBridge` wired into `MaterialApp.builder`
- [ ] No `GoogleFonts.*TextTheme()` anywhere
- [ ] Route transitions still animate (explicit `pageBuilder` if go_router)
- [ ] `flutter_localizations` not declared; delegates from material_ui
- [ ] Analyze clean, tests pass, and the app has been *run* — the two worst
      failures here do not fail a build
