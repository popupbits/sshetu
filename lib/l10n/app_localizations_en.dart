// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SSH Navigator';

  @override
  String get navHosts => 'Hosts';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navKeys => 'Keys';

  @override
  String get navTunnels => 'Tunnels';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionOk => 'OK';

  @override
  String get actionClose => 'Close';

  @override
  String get comingSoon => 'Nothing here yet';

  @override
  String get comingSoonBody =>
      'This screen is a placeholder. Replace it with the real thing.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get themeSystem => 'Match device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'Match device';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageNepali => 'Nepali';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeDefault => 'Default';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get textSizeLarger => 'Larger';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentForest => 'Forest';

  @override
  String get accentAmber => 'Amber';

  @override
  String get accentCoral => 'Coral';

  @override
  String get accentRose => 'Rose';

  @override
  String get accentMauve => 'Mauve';

  @override
  String get accentSlate => 'Slate';

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutPrivacyPolicy => 'Privacy policy';

  @override
  String get aboutPrivacyPolicySubtitle =>
      'What we collect, and what we don\'t';

  @override
  String get aboutLicenses => 'Open-source licences';

  @override
  String get aboutLicensesSubtitle => 'Third-party packages this app uses';

  @override
  String get aboutShare => 'Share SSH Navigator';

  @override
  String get aboutShareSubtitle => 'Tell someone who\'d find it useful';

  @override
  String get aboutShareMessage =>
      'I\'ve been using SSH Navigator — you might like it too.';

  @override
  String get aboutRate => 'Rate SSH Navigator';

  @override
  String get aboutRateSubtitle => 'A rating genuinely helps';

  @override
  String get aboutMoreApps => 'More apps';

  @override
  String get aboutMoreAppsSubtitle => 'Other apps we make';

  @override
  String get aboutSupport => 'Contact support';

  @override
  String get aboutSupportSubtitle => '';

  @override
  String get aboutSupportSubject => 'SSH Navigator support';

  @override
  String errorCouldNotOpen(String target) {
    return 'Couldn\'t open $target';
  }

  @override
  String get updateReadyTitle => 'Update downloaded';

  @override
  String get updateRestart => 'Restart';

  @override
  String get updateStuck => 'An update is waiting to finish';

  @override
  String get updateOpenStore => 'Open Play Store';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authName => 'Name';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNoAccount => 'No account yet? Create one';

  @override
  String get authHaveAccount => 'Already have an account? Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignOutConfirm => 'Sign out of SSH Navigator?';

  @override
  String get authAccount => 'Account';

  @override
  String get authEmailRequired => 'Enter your email';

  @override
  String get authEmailInvalid => 'That doesn\'t look like an email address';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authPasswordTooShort => 'Passwords must be at least 8 characters';

  @override
  String get authNameRequired => 'Enter your name';

  @override
  String get authRecoverySent => 'Check your email for a reset link';

  @override
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String settingsDiagnosticsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recent errors',
      one: '1 recent error',
    );
    return '$_temp0';
  }

  @override
  String get settingsDiagnosticsNone => 'Nothing to report';

  @override
  String get diagnosticsEmpty => 'No errors recorded';

  @override
  String get diagnosticsEmptyBody =>
      'When something goes wrong, it is collected here so you can send us the details.';

  @override
  String get diagnosticsShare => 'Share report';

  @override
  String get diagnosticsShareSubject => 'SSH Navigator diagnostics';

  @override
  String get diagnosticsClear => 'Clear';

  @override
  String get diagnosticsClearConfirm => 'Clear all recorded errors?';

  @override
  String diagnosticsSeenTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seen $count times',
      one: 'seen once',
    );
    return '$_temp0';
  }

  @override
  String get hostsTitle => 'Hosts';

  @override
  String get hostsEmptyTitle => 'No servers yet';

  @override
  String get hostsEmptyBody =>
      'Add a server, or import the ones already on this machine.';

  @override
  String get hostsAdd => 'Add host';

  @override
  String get hostsImport => 'Import from OpenSSH';

  @override
  String get hostsSearch => 'Search hosts';

  @override
  String get hostsConnect => 'Connect';

  @override
  String get hostsEdit => 'Edit';

  @override
  String get hostsDelete => 'Delete';

  @override
  String get hostsDeleteConfirm => 'Delete this host?';

  @override
  String get hostsDeleteBody =>
      'Its saved password is destroyed. Keys and known-host entries are left alone.';

  @override
  String get hostsNeverConnected => 'Never connected';

  @override
  String get hostEditorNew => 'New host';

  @override
  String get hostEditorEdit => 'Edit host';

  @override
  String get hostEditorLabel => 'Name';

  @override
  String get hostEditorLabelHint => 'What you call it — \"build box\"';

  @override
  String get hostEditorHostname => 'Host';

  @override
  String get hostEditorHostnameHint => 'example.com or 10.0.0.4';

  @override
  String get hostEditorPort => 'Port';

  @override
  String get hostEditorUsername => 'Username';

  @override
  String get hostEditorAuth => 'Authentication';

  @override
  String get hostEditorAuthKey => 'Private key';

  @override
  String get hostEditorAuthPassword => 'Password';

  @override
  String get hostEditorIdentity => 'Key';

  @override
  String get hostEditorIdentityNone => 'No key selected';

  @override
  String get hostEditorJump => 'Connect through';

  @override
  String get hostEditorJumpNone => 'Direct';

  @override
  String get hostEditorAdvanced => 'Advanced';

  @override
  String get hostEditorStartup => 'Startup command';

  @override
  String get hostEditorStartupHint => 'tmux new -A -s main';

  @override
  String get hostEditorLegacy => 'Allow legacy algorithms';

  @override
  String get hostEditorSave => 'Save';

  @override
  String get hostEditorRequired => 'Required';

  @override
  String get hostEditorPortInvalid => '1–65535';

  @override
  String get terminalConnecting => 'Connecting…';

  @override
  String get terminalDisconnect => 'Disconnect';

  @override
  String get terminalReconnect => 'Reconnect';

  @override
  String get terminalCloseTab => 'Close tab';

  @override
  String get terminalPaste => 'Paste';

  @override
  String get terminalCopy => 'Copy';

  @override
  String get sessionsEmptyTitle => 'No open sessions';

  @override
  String get sessionsEmptyBody => 'Connect to a host and it appears here.';

  @override
  String get hostKeyTitle => 'Unknown host';

  @override
  String get hostKeyTrust => 'Trust and connect';

  @override
  String get hostKeyChangedTitle => 'Host identity changed';

  @override
  String get hostKeyFingerprint => 'Fingerprint';

  @override
  String get secretPasswordTitle => 'Password';

  @override
  String get secretPassphraseTitle => 'Key passphrase';

  @override
  String get secretRemember => 'Remember on this device';

  @override
  String get secretUnlock => 'Unlock';

  @override
  String get keysTitle => 'Keys';

  @override
  String get keysEmptyTitle => 'No keys yet';

  @override
  String get keysEmptyBody =>
      'Import the keys already in your ~/.ssh, or paste one in.';

  @override
  String get keysImport => 'Import keys';

  @override
  String get keysCopyPublic => 'Copy public key';

  @override
  String get keysCopied => 'Public key copied';

  @override
  String get keysEncrypted => 'Passphrase-protected';

  @override
  String get keysDelete => 'Delete key';

  @override
  String get keysDeleteConfirm => 'Delete this key?';

  @override
  String get keysDeleteBody =>
      'The private key is destroyed on this device and cannot be recovered.';

  @override
  String get importTitle => 'Import from OpenSSH';

  @override
  String get importScanning => 'Looking for an existing setup…';

  @override
  String importFoundIn(String path) {
    return 'Found in $path';
  }

  @override
  String get importNothingTitle => 'Nothing found';

  @override
  String get importNothingBody =>
      'No ~/.ssh directory with hosts or keys was found on this device.';

  @override
  String get importUnavailableTitle => 'Not available here';

  @override
  String get importUnavailableBody =>
      'This device has no ~/.ssh to read. Import a key file instead.';

  @override
  String get importHostsSection => 'Hosts';

  @override
  String get importKeysSection => 'Keys';

  @override
  String get importSelectAll => 'Select all';

  @override
  String get importSelectNone => 'Select none';

  @override
  String importAction(int count) {
    return 'Import $count items';
  }

  @override
  String importDone(int hosts, int keys) {
    return 'Imported $hosts hosts and $keys keys';
  }

  @override
  String importUnsupported(String options) {
    return 'Not imported: $options';
  }

  @override
  String get importRescan => 'Scan again';

  @override
  String get importNoteTitle => 'Read-only';

  @override
  String get importNoteBody => 'Your ~/.ssh files are read, never changed.';

  @override
  String get tunnelsEmptyTitle => 'No port forwards';

  @override
  String get tunnelsEmptyBody => 'Port forwarding is not wired up yet.';

  @override
  String get settingsSync => 'Sync';

  @override
  String get settingsSyncSignIn => 'Sign in to sync';

  @override
  String get settingsSyncBody =>
      'Optional. Everything works on this device without an account.';

  @override
  String get importChooseFolder => 'Choose folder';

  @override
  String get importChooseFolderConfirm => 'Read this folder';

  @override
  String get importChooseFolderBody =>
      'Choose your .ssh folder so it can be read. Nothing in it is changed.';
}
