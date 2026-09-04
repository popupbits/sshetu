/// The shortest passphrase the export will accept.
///
/// Not a security claim — eight characters is weak and the meter says so. It
/// is a floor under the obvious mistakes ("abc"), placed where someone can
/// still be told, rather than a rule that lets them think a short passphrase
/// was approved.
const int kMinimumPassphrase = 8;

enum PassphraseStrength { weak, fair, strong }

/// A rough, honest read on a passphrase.
///
/// Deliberately crude. A real estimator (zxcvbn and its dictionaries) is a
/// dependency and a megabyte, and the decision it informs here is binary:
/// should this person think again? Length dominates that answer, and length
/// is what this counts — with a nudge for variety, because "aaaaaaaaaaaaaaaa"
/// is long and worthless.
PassphraseStrength strengthOf(String passphrase) {
  if (passphrase.length < 12) return PassphraseStrength.weak;

  final distinct = passphrase.split('').toSet().length;
  if (distinct < 5) return PassphraseStrength.weak;

  final words = passphrase.trim().split(RegExp(r'\s+')).length;
  // Four words is the passphrase advice everyone has heard, and it is good
  // advice: a memorable sentence beats a short scramble.
  if (words >= 4 || passphrase.length >= 20) return PassphraseStrength.strong;

  return PassphraseStrength.fair;
}
