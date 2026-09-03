import '../../l10n/app_localizations.dart';

/// Form validation shared by the sign-in and sign-up screens.
///
/// Appwrite's minimum password length is 8. Enforcing it client-side turns a
/// round trip and a red banner into an inline hint before the user submits.
const int minPasswordLength = 8;

/// Deliberately permissive: the only authority on whether an address works is
/// whether mail to it arrives. This catches typos like a missing `@`, and
/// nothing else.
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value, AppLocalizations l10n) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return l10n.authEmailRequired;
  if (!_emailPattern.hasMatch(email)) return l10n.authEmailInvalid;
  return null;
}

String? validatePasswordPresent(String? value, AppLocalizations l10n) {
  if ((value ?? '').isEmpty) return l10n.authPasswordRequired;
  return null;
}

String? validateNewPassword(String? value, AppLocalizations l10n) {
  final password = value ?? '';
  if (password.isEmpty) return l10n.authPasswordRequired;
  if (password.length < minPasswordLength) return l10n.authPasswordTooShort;
  return null;
}
