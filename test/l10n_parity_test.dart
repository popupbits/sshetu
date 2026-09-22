import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// Every translation says the same things as the English template.
///
/// `flutter gen-l10n` does not fail when a locale is missing a key — it falls
/// back to English for that string and prints a note nobody reads, so a
/// Nepali screen quietly grows English labels one feature at a time. Nor does
/// it notice a translation that dropped a placeholder: `{count}` missing from
/// the Nepali text compiles and simply never shows the number. This test turns
/// both into a failure.
///
/// **Adding an English string without its Nepali one fails here.** That is
/// the point: add the key to every `app_*.arb`, then run `flutter gen-l10n`.
void main() {
  const dir = 'lib/l10n';
  const templateName = 'app_en.arb';

  Map<String, dynamic> read(File file) =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  Map<String, String> messages(Map<String, dynamic> arb) => {
    for (final e in arb.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };

  final template = read(File('$dir/$templateName'));
  final templateMessages = messages(template);

  final translations = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(f.path))
      .where((f) => !f.path.endsWith(templateName))
      .toList();

  test('there is at least one translation to check', () {
    expect(translations, isNotEmpty);
  });

  test('every template message parses as ICU', () {
    final errors = <String>[];
    templateMessages.forEach((key, value) {
      try {
        IcuMessage.parse(value);
      } on FormatException catch (e) {
        errors.add('$key: ${e.message}');
      }
    });
    expect(errors, isEmpty);
  });

  for (final file in translations) {
    final name = file.uri.pathSegments.last;
    final locale = RegExp(r'app_(.+)\.arb$').firstMatch(name)!.group(1)!;

    group(name, () {
      final arb = read(file);
      final translated = messages(arb);

      test('"@@locale" matches the file name', () {
        expect(arb['@@locale'], locale);
      });

      test('carries no metadata — that lives only in the template', () {
        final metadata = arb.keys
            .where((k) => k.startsWith('@') && k != '@@locale')
            .toList();
        expect(metadata, isEmpty);
      });

      test('has every template key', () {
        final missing = templateMessages.keys
            .where((k) => !translated.containsKey(k))
            .toList();
        expect(
          missing,
          isEmpty,
          reason: 'add these to $name (and to every other app_*.arb)',
        );
      });

      test('has no key the template lacks', () {
        final extra = translated.keys
            .where((k) => !templateMessages.containsKey(k))
            .toList();
        expect(extra, isEmpty, reason: 'stale or misspelled keys in $name');
      });

      test('every message parses, with the template\'s placeholders and '
          'plural/select structure', () {
        final errors = <String>[];
        for (final key in templateMessages.keys) {
          final value = translated[key];
          if (value == null) continue; // reported by 'has every template key'
          final IcuMessage theirs;
          try {
            theirs = IcuMessage.parse(value);
          } on FormatException catch (e) {
            errors.add('$key: ${e.message}');
            continue;
          }
          final ours = IcuMessage.parse(templateMessages[key]!);

          if (!_setEquals(ours.placeholders, theirs.placeholders)) {
            errors.add(
              '$key: placeholders ${theirs.placeholders} but the template '
              'has ${ours.placeholders}',
            );
          }
          ours.selectors.forEach((arg, kind) {
            final other = theirs.selectors[arg];
            if (other == null) {
              errors.add('$key: {$arg, $kind} is missing');
            } else if (other != kind) {
              errors.add('$key: {$arg} is $other, the template has $kind');
            }
          });
          for (final arg in theirs.selectors.keys) {
            if (!ours.selectors.containsKey(arg)) {
              errors.add('$key: {$arg, ${theirs.selectors[arg]}} is extra');
            }
          }
          // A select's cases are values the code passes in, so a translation
          // must match them exactly; a missing one would show "other".
          ours.selectCases.forEach((arg, cases) {
            final other = theirs.selectCases[arg];
            if (other != null && !_setEquals(cases, other)) {
              errors.add(
                '$key: {$arg, select} cases $other, the template has $cases',
              );
            }
          });
        }
        expect(errors, isEmpty);
      });

      test('is listed in AppLocalizations.supportedLocales', () {
        // Fails when the .arb was added but `flutter gen-l10n` was not run.
        expect(
          AppLocalizations.supportedLocales.map((l) => l.toLanguageTag()),
          contains(locale.replaceAll('_', '-')),
        );
      });
    });
  }

  group('IcuMessage', () {
    test('reads plain placeholders', () {
      expect(IcuMessage.parse('Log {file} to {path}').placeholders, {
        'file',
        'path',
      });
    });

    test('reads a plural and the placeholders inside it', () {
      final m = IcuMessage.parse(
        '{count, plural, =1{1 line in {name}} other{{count} lines}}',
      );
      expect(m.placeholders, {'count', 'name'});
      expect(m.selectors, {'count': 'plural'});
    });

    test('reads a select and its cases', () {
      final m = IcuMessage.parse('{os, select, linux{Linux} other{Other}}');
      expect(m.selectCases, {
        'os': {'linux', 'other'},
      });
    });

    test('rejects a plural without other', () {
      expect(
        () => IcuMessage.parse('{count, plural, =1{one}}'),
        throwsFormatException,
      );
    });

    test('rejects an unknown plural category', () {
      expect(
        () => IcuMessage.parse('{count, plural, some{x} other{y}}'),
        throwsFormatException,
      );
    });

    test('rejects unbalanced braces', () {
      expect(() => IcuMessage.parse('Hello {name'), throwsFormatException);
      expect(() => IcuMessage.parse('Hello name}'), throwsFormatException);
      expect(
        () => IcuMessage.parse('{count, plural, other{x}'),
        throwsFormatException,
      );
    });
  });
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

/// Just enough of ICU MessageFormat to compare two messages' shapes: simple
/// `{name}` arguments, and `plural` / `select` with nested messages.
///
/// gen-l10n here runs without `use-escaping`, so apostrophes are literal and
/// are not treated as quotes.
class IcuMessage {
  IcuMessage._();

  /// Every argument name used anywhere, including inside branches.
  final Set<String> placeholders = {};

  /// Argument name → `plural` or `select`.
  final Map<String, String> selectors = {};

  /// Select argument name → its case keys.
  final Map<String, Set<String>> selectCases = {};

  static const _pluralCategories = {
    'zero',
    'one',
    'two',
    'few',
    'many',
    'other',
  };

  static IcuMessage parse(String source) {
    final message = IcuMessage._();
    final end = message._message(source, 0, nested: false);
    if (end != source.length) {
      throw FormatException('unexpected "}" at $end', source, end);
    }
    return message;
  }

  /// Parses text and arguments from [i] until an unmatched `}` (when
  /// [nested]) or the end; returns the index it stopped at.
  int _message(String s, int i, {required bool nested}) {
    while (i < s.length) {
      final c = s[i];
      if (c == '{') {
        i = _argument(s, i + 1);
      } else if (c == '}') {
        if (nested) return i;
        throw FormatException('unexpected "}" at $i', s, i);
      } else {
        i++;
      }
    }
    if (nested) throw FormatException('unclosed branch', s, i);
    return i;
  }

  /// Parses an argument whose `{` is just before [i]; returns the index after
  /// its closing `}`.
  int _argument(String s, int i) {
    final nameEnd = _indexOfAny(s, i, const [',', '}']);
    final name = s.substring(i, nameEnd).trim();
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
      throw FormatException('bad argument name "$name"', s, i);
    }
    placeholders.add(name);
    if (s[nameEnd] == '}') return nameEnd + 1;

    final typeEnd = _indexOfAny(s, nameEnd + 1, const [',', '}']);
    final type = s.substring(nameEnd + 1, typeEnd).trim();
    if (type != 'plural' && type != 'select') {
      // A formatted argument such as {n, number}: nothing nested to check.
      final close = s.indexOf('}', typeEnd);
      if (close < 0) throw FormatException('unclosed "{$name"', s, i);
      return close + 1;
    }
    if (s[typeEnd] != ',') {
      throw FormatException('{$name, $type} has no branches', s, i);
    }
    if (selectors.containsKey(name) && selectors[name] != type) {
      throw FormatException('{$name} is both plural and select', s, i);
    }
    selectors[name] = type;

    final keys = <String>{};
    var j = typeEnd + 1;
    while (true) {
      while (j < s.length && s[j].trim().isEmpty) {
        j++;
      }
      if (j >= s.length) throw FormatException('unclosed "{$name"', s, i);
      if (s[j] == '}') {
        j++;
        break;
      }
      final keyEnd = _indexOfAny(s, j, const ['{', ' ', '\t', '\n', '}']);
      final key = s.substring(j, keyEnd);
      if (key.isEmpty) throw FormatException('empty branch key', s, j);
      if (type == 'plural' &&
          !_pluralCategories.contains(key) &&
          !RegExp(r'^=\d+$').hasMatch(key)) {
        throw FormatException('{$name}: "$key" is not a plural category', s, j);
      }
      if (!keys.add(key)) {
        throw FormatException('{$name}: branch "$key" repeated', s, j);
      }
      j = keyEnd;
      while (j < s.length && s[j].trim().isEmpty) {
        j++;
      }
      if (j >= s.length || s[j] != '{') {
        throw FormatException('{$name}: branch "$key" has no message', s, j);
      }
      j = _message(s, j + 1, nested: true) + 1;
    }
    if (!keys.contains('other')) {
      throw FormatException('{$name, $type} has no "other" branch', s, i);
    }
    if (type == 'select') selectCases[name] = keys;
    return j;
  }

  static int _indexOfAny(String s, int from, List<String> chars) {
    for (var k = from; k < s.length; k++) {
      if (chars.contains(s[k])) return k;
    }
    throw FormatException('unterminated argument', s, from);
  }
}
