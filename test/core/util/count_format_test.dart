import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sshetu/core/util/count_format.dart';

/// Counts are grouped, in Latin digits, whatever the app's language.
void main() {
  test('groups with Latin digits', () {
    expect(formatCount(0), '0');
    expect(formatCount(999), '999');
    expect(formatCount(10000), '10,000');
    expect(formatCount(1000000), '1,000,000');
  });

  test('ignores the ambient locale, Nepali included', () {
    final previous = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previous);
    Intl.defaultLocale = 'ne';
    expect(formatCount(10000), '10,000');
    expect(formatCount(10000), isNot(contains(RegExp('[०-९]'))));
  });
}
