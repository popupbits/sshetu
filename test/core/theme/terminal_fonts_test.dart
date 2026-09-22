import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/theme/terminal_fonts.dart';
import 'package:sshetu/core/theme/terminal_theme.dart';

/// The terminal faces are bundled, not fetched: a face that depends on a
/// network draws the grid in a fallback on an offline first launch. These
/// tests are what keeps "bundled" true.
void main() {
  final pubspec = File('pubspec.yaml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');
  final bundled = TerminalFonts.all.where((f) => !f.isSystem);

  test('the default is the platform monospace', () {
    expect(TerminalFonts.byId(null), TerminalFonts.system);
    expect(TerminalFonts.system.id, TerminalFonts.defaultId);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    // Never the generic `monospace`, which Windows draws proportionally.
    expect(TerminalFonts.system.resolvedFamily, 'Cascadia Mono');
  });

  test('an unknown id is the system face', () {
    expect(TerminalFonts.byId('comic-mono').id, 'system');
  });

  for (final font in bundled) {
    group(font.family!, () {
      test('is declared as a font family in pubspec.yaml', () {
        expect(pubspec, contains('- family: ${font.family}\n'));
      });

      test('has its Regular and Bold files in the repository', () {
        final block = pubspec
            .split('- family: ${font.family}\n')
            .last
            .split('- family:')
            .first;
        final assets = RegExp(r'asset: (\S+\.ttf)')
            .allMatches(block)
            .map((m) => m.group(1)!)
            .toList();
        expect(assets, hasLength(2), reason: 'Regular and Bold');
        expect(block, contains('weight: 700'));
        for (final asset in assets) {
          expect(
            File(asset).lengthSync(),
            greaterThan(50000),
            reason: '$asset should be a real font, not an error page',
          );
        }
      });

      test('ships its licence text', () {
        final licence = font.licenseAsset!;
        expect(pubspec, contains('- $licence'));
        expect(
          File(licence).readAsStringSync(),
          contains('SIL Open Font License'),
        );
      });

      test('is actually monospaced', () async {
        final block = pubspec
            .split('- family: ${font.family}\n')
            .last
            .split('- family:')
            .first;
        final regular = RegExp(r'asset: (\S+\.ttf)').firstMatch(block)!;
        final bytes = File(regular.group(1)!).readAsBytesSync();
        final loader = FontLoader(font.family!)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();

        double width(String text) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(fontFamily: font.family, fontSize: 20),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          addTearDown(painter.dispose);
          return painter.width;
        }

        expect(width('iiiiiiiiii'), closeTo(width('MMMMMMMMMM'), 0.01));
        expect(width('..........'), closeTo(width('WWWWWWWWWW'), 0.01));
      });
    });
  }

  test('a bundled face falls back to the platform monospace first', () {
    expect(TerminalFonts.jetBrainsMono.fallback.first, Mono.family);
    expect(TerminalFonts.jetBrainsMono.fallback, containsAll(Mono.fallback));
  });

  group('ligatures', () {
    // Fira Code draws `=>`, `!=` and `->` as single glyphs by default. In a
    // terminal every character owns a cell the remote program addressed, so
    // a ligature is two cells drawn as one — wrong, and wrong differently
    // from what the server thinks is on screen.
    for (final font in TerminalFonts.all) {
      test('${font.id} disables them', () {
        final features = font.style(13).toTextStyle().fontFeatures ?? const [];
        for (final tag in ['liga', 'calt', 'clig', 'dlig']) {
          expect(
            features,
            contains(FontFeature.disable(tag)),
            reason: '$tag must be off',
          );
        }
      });
    }
  });

  test('the style carries the chosen face and size', () {
    final style = TerminalFonts.firaCode.style(17);
    expect(style.fontFamily, 'Fira Code');
    expect(style.fontSize, 17);
  });
}
