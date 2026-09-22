import 'package:intl/intl.dart';

/// A count for the UI, grouped, in Latin digits in every language.
///
/// One rule for numerals across the app, Nepali included: Latin digits
/// (0–9), never Devanagari (०–९). Most numbers this app shows are not its
/// own — ports, addresses, PIDs, sizes and uptimes come from the server, and
/// the terminal beside them is Latin — so Latin is the only choice that can
/// be applied everywhere. It is also what Nepali software commonly uses. The
/// alternative left the UI mixed: counts interpolated into a string printed
/// "3" while the one placeholder formatted with `NumberFormat` in the `ne`
/// locale printed "१०,०००".
///
/// So a placeholder that wants grouping takes a `String` formatted here,
/// rather than `"format": "decimalPattern"` in the `.arb`, which formats in
/// the current locale's digits. `test/l10n_latin_digits_test.dart` holds the
/// `.arb` files to that.
String formatCount(int value) => _grouped.format(value);

final NumberFormat _grouped = NumberFormat.decimalPattern('en');
