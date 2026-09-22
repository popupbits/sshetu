import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/theme/accent.dart';
import 'package:sshetu/core/theme/app_theme.dart';
import 'package:sshetu/core/theme/script_fallback.dart';
import 'package:sshetu/core/theme/terminal_fonts.dart';
import 'package:sshetu/core/theme/terminal_theme.dart';

/// Nepali has to be drawn in something. Inter and every bundled terminal face
/// are Latin-only, so without a Devanagari face on the fallback list the
/// Nepali UI — and `echo नमस्ते` in a terminal — depends on whatever the
/// platform happens to guess, and shows boxes where it guesses nothing.
void main() {
  test('names a Devanagari face for every platform SSHetu ships on', () {
    expect(ScriptFallback.devanagari, contains('Noto Sans Devanagari'));
    expect(ScriptFallback.devanagari, contains('Kohinoor Devanagari'));
    expect(ScriptFallback.devanagari, contains('Nirmala UI'));
  });

  testWidgets('every UI text style falls back to Devanagari', (tester) async {
    for (final theme in [
      AppTheme.light(Accents.indigo),
      AppTheme.dark(Accents.indigo),
    ]) {
      final t = theme.textTheme;
      for (final style in [
        t.displayLarge,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelSmall,
      ]) {
        expect(
          style?.fontFamilyFallback,
          containsAll(ScriptFallback.devanagari),
        );
      }
    }
  });

  test('the terminal falls back to Devanagari, after the monospaced faces', () {
    expect(Mono.fallback, containsAll(ScriptFallback.devanagari));
    // A gap in the chosen face is filled by something monospaced first.
    expect(
      Mono.fallback.indexOf('monospace'),
      lessThan(Mono.fallback.indexOf(ScriptFallback.devanagari.first)),
    );
    for (final font in TerminalFonts.all) {
      expect(
        font.style(13).fontFamilyFallback,
        containsAll(ScriptFallback.devanagari),
      );
    }
  });
}
