import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/theme/accent.dart';
import 'package:sshetu/core/theme/terminal_theme.dart';
import 'package:sshetu/core/theme/terminal_theme_presets.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every colour scheme the adaptive preset can be built from: each accent, in
/// both modes. Built the way `AppTheme` builds it, without the font loading
/// that `AppTheme` pulls in.
Iterable<ColorScheme> appSchemes() sync* {
  for (final accent in Accents.all) {
    for (final brightness in Brightness.values) {
      yield ColorScheme.fromSeed(
        seedColor: accent.forBrightness(brightness),
        brightness: brightness,
      );
    }
  }
}

void main() {
  test('the WCAG helper agrees with known values', () {
    expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)), 21);
    expect(
      contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
    );
  });

  test('ships the promised presets, default first', () {
    expect(TerminalThemePresets.all.map((p) => p.id), [
      'sshetu',
      'dracula',
      'nord',
      'solarized-dark',
      'solarized-light',
      'gruvbox-dark',
      'tokyo-night',
      'one-dark',
      'monokai',
    ]);
    expect(TerminalThemePresets.all.first.id, TerminalThemePresets.defaultId);
  });

  test('ids and names are unique', () {
    final ids = TerminalThemePresets.all.map((p) => p.id).toList();
    final names = TerminalThemePresets.all.map((p) => p.name).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(names.toSet(), hasLength(names.length));
  });

  test('only the default is adaptive', () {
    expect(
      TerminalThemePresets.all.where((p) => p.isAdaptive).map((p) => p.id),
      [TerminalThemePresets.defaultId],
    );
  });

  group('every fixed palette', () {
    for (final preset in TerminalThemePresets.all.where((p) => !p.isAdaptive)) {
      final palette = preset.palette!;

      test('${preset.name} has sixteen opaque ANSI colours', () {
        expect(palette.ansi, hasLength(TerminalPalette.ansiCount));
        for (final color in [
          ...palette.ansi,
          palette.foreground,
          palette.background,
          palette.cursor,
          palette.selection,
        ]) {
          expect(color.a, 1.0, reason: '$color in ${preset.name}');
        }
      });

      test('${preset.name} text is legible (≥ 4.5:1)', () {
        final ratio = contrast(palette.foreground, palette.background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${preset.name}: ${ratio.toStringAsFixed(2)}:1',
        );
      });

      test('${preset.name} becomes a whole xterm2 theme', () {
        final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5));
        final theme = preset.toTerminalTheme(scheme);
        expect(theme.background, palette.background);
        expect(theme.foreground, palette.foreground);
        expect(theme.red, palette.ansi[1]);
        expect(theme.brightWhite, palette.ansi[15]);
        // Fixed means fixed: the app's colours must not leak in.
        final other = preset.toTerminalTheme(
          ColorScheme.fromSeed(
            seedColor: const Color(0xFFE91E63),
            brightness: Brightness.dark,
          ),
        );
        expect(other.background, theme.background);
        expect(other.cursor, theme.cursor);
      });
    }
  });

  group('the adaptive default', () {
    test('has sixteen colours and legible text for every accent and mode', () {
      for (final scheme in appSchemes()) {
        final palette = TerminalThemePresets.sshetu.paletteFor(scheme);
        expect(palette.ansi, hasLength(TerminalPalette.ansiCount));
        expect(
          contrast(palette.foreground, palette.background),
          greaterThanOrEqualTo(4.5),
          reason: '${scheme.brightness} ${scheme.primary}',
        );
      }
    });

    test('follows light and dark', () {
      final light = TerminalThemePresets.sshetu.paletteFor(
        ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
      );
      final dark = TerminalThemePresets.sshetu.paletteFor(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: Brightness.dark,
        ),
      );
      expect(light.isLight, isTrue);
      expect(dark.isLight, isFalse);
      expect(light.ansi, isNot(dark.ansi));
    });
  });

  group('lookup', () {
    test('an unknown or missing id is the default', () {
      expect(TerminalThemePresets.byId('solarized-neon').id, 'sshetu');
      expect(TerminalThemePresets.byId(null).id, 'sshetu');
      expect(TerminalThemePresets.byId('').id, 'sshetu');
    });

    test('a known id is itself', () {
      expect(TerminalThemePresets.byId('nord'), TerminalThemePresets.nord);
    });
  });

  group('per-host resolution', () {
    test('no override follows the app setting', () {
      expect(
        TerminalThemePresets.resolve(hostOverride: null, appDefault: 'nord').id,
        'nord',
      );
    });

    test('an override wins', () {
      expect(
        TerminalThemePresets.resolve(
          hostOverride: 'dracula',
          appDefault: 'nord',
        ).id,
        'dracula',
      );
    });

    test('an override this build does not know falls back to the setting', () {
      // Not to the built-in default: the user chose Nord for everything, and
      // a host naming a preset from a newer build should look like the rest.
      expect(
        TerminalThemePresets.resolve(
          hostOverride: 'from-the-future',
          appDefault: 'nord',
        ).id,
        'nord',
      );
    });

    test('an unknown app setting falls back to the default', () {
      expect(
        TerminalThemePresets.resolve(hostOverride: null, appDefault: 'gone').id,
        'sshetu',
      );
    });
  });
}
