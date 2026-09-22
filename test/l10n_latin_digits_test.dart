import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One rule for numerals: Latin digits in every language (see
/// `lib/core/util/count_format.dart` for why).
///
/// gen-l10n formats a numeric placeholder carrying a `"format"` with
/// `NumberFormat` in the *current* locale, which in Nepali prints Devanagari
/// digits ("१०,०००") beside strings that print Latin ones ("3 कल"). A
/// placeholder that wants grouping takes a `String` from `formatCount`
/// instead. Plural counts are fine: they interpolate with `toString`.
void main() {
  final template = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('no numeric placeholder is formatted in the locale digits', () {
    final offenders = <String>[];
    for (final entry in template.entries) {
      if (!entry.key.startsWith('@')) continue;
      final meta = entry.value;
      if (meta is! Map<String, dynamic>) continue;
      final placeholders =
          (meta['placeholders'] as Map<String, dynamic>?) ?? const {};
      for (final placeholder in placeholders.entries) {
        final spec = placeholder.value as Map<String, dynamic>;
        final type = spec['type'];
        if ((type == 'int' || type == 'double' || type == 'num') &&
            spec.containsKey('format')) {
          offenders.add('${entry.key.substring(1)}.${placeholder.key}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no translation writes Devanagari digits into its text', () {
    for (final file in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb')) continue;
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in arb.entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        expect(
          entry.value as String,
          isNot(contains(RegExp('[०-९]'))),
          reason: '${file.path}: ${entry.key}',
        );
      }
    }
  });
}
