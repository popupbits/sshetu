# Flutter implementation notes

Framework-specific ways the principles in SKILL.md go wrong, and how to wire
them up so they hold.

## Tokens as real code

Put the scale in one file and import it everywhere. Constants beat comments.

```dart
abstract final class Space {
  static const xs = 4.0, sm = 8.0, md = 12.0, base = 16.0;
  static const lg = 24.0, xl = 32.0, xxl = 48.0;
}

abstract final class Radii {
  static const sm = 8.0, md = 14.0, lg = 22.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
}
```

## Theming an accent the user can change

Build `ThemeData` from a seed so one value drives everything:

```dart
ThemeData buildTheme(Color accent, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  );
  return ThemeData(colorScheme: scheme, useMaterial3: true, ...);
}
```

Then the accent must actually reach the widgets:

- **Audit for hardcoded colours first.** `grep -rn "Color(0xFF\|Colors\.blue"
  lib/` — every hit is a place the user's choice will be ignored. This is the
  bulk of the work in an accent revamp, not the picker.
- Read colour from `Theme.of(context).colorScheme.primary`, not a constant.
- Persist the choice and rebuild the app on change (`Get.changeTheme`,
  `ValueNotifier<ThemeData>`, or a provider above `MaterialApp`).
- Keep semantic colours (success/warning/error) *outside* the seed — they must
  not shift when the accent changes.

## Things Flutter does not inherit

- **`Get.bottomSheet` ignores `ThemeData.bottomSheetTheme`.** Omit
  `backgroundColor` and the sheet renders transparent. `showModalBottomSheet`
  does inherit it. Wrap whichever you use in one helper so it can't drift.
- `Get.dialog` similarly needs its own shape/colour unless `dialogTheme` is
  set and the widget is a plain `AlertDialog`.
- `TextField` inside a sheet needs `isScrollControlled: true` plus
  `MediaQuery.of(context).viewInsets.bottom` padding, or the keyboard covers
  it.

## Reactivity traps that look like design bugs

With GetX, `Obx` only tracks observables read **synchronously inside its own
builder**. A read inside a callback that runs later registers nothing:

```dart
// BROKEN — itemBuilder runs during layout, after the Obx builder returned.
Obx(() => ListView.builder(
  itemBuilder: (_, i) => Text(controller.items[i].name),  // tracks nothing
));

// CORRECT — read it in the builder body.
Obx(() {
  final items = controller.items.toList();
  return ListView.builder(itemBuilder: (_, i) => Text(items[i].name));
});
```

The same applies to reading an observable in `bottomNavigationBar:`,
`Builder(builder:)`, or any slot evaluated lazily. Symptom: the UI updates
only after some *other* rebuild, so it looks like a stale-state design bug.

## Text and layout robustness

- `Text(..., maxLines: 1, overflow: TextOverflow.ellipsis)` on anything
  showing user or network data.
- Wrap flexible text in `Expanded`/`Flexible` inside a `Row`, or long strings
  throw overflow errors instead of truncating.
- Avoid fixed `height:` on containers holding text — they clip at large text
  scale. Use padding and let content size it.
- `MediaQuery.textScalerOf(context)` to sanity-check large-text layouts.

## Fonts

`google_fonts` fetches at runtime by default. Offline that throws into your
error handler and produces phantom crash reports, and the first paint blocks.
Bundle the `.ttf` in `assets/`, declare it in `pubspec.yaml`, and set
`GoogleFonts.config.allowRuntimeFetching = false`.

## States

```dart
switch (state) {
  Loading() => const SkeletonList(),       // not a bare spinner
  Empty()   => EmptyState(                  // teaches the screen
      icon: ..., title: ..., body: ..., action: ...),
  Failure(:final message) => ErrorState(message: message, onRetry: ...),
  Ready(:final items) => ContentList(items),
}
```

Skeletons: match the real layout's shape and spacing, animate a subtle
shimmer, and never show them for under ~200ms (flashing is worse than
waiting).

## Quick audit commands

```bash
grep -rn "Color(0xFF" lib/            # hardcoded colours
grep -rn "Colors\.\(blue\|red\|green\)" lib/
grep -rn "fontSize: 1[0-4][^0-9]" lib/  # text below the ramp floor
grep -rn "height: [0-9]" lib/ | grep -i "container\|sizedbox"  # fixed heights
```
