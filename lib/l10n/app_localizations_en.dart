// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SSHetu';

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
  String get actionShow => 'Show';

  @override
  String get actionHide => 'Hide';

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
  String get settingsTerminalTextSize => 'Terminal text size';

  @override
  String terminalTextSizePoints(int size) {
    return '$size pt';
  }

  @override
  String get terminalTextSizeSmaller => 'Smaller';

  @override
  String get terminalTextSizeLarger => 'Larger';

  @override
  String get menuZoomIn => 'Zoom In';

  @override
  String get menuZoomOut => 'Zoom Out';

  @override
  String get menuActualSize => 'Actual Size';

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
  String get aboutShare => 'Share SSHetu';

  @override
  String get aboutShareSubtitle => 'Tell someone who\'d find it useful';

  @override
  String get aboutShareMessage =>
      'I\'ve been using SSHetu — you might like it too.';

  @override
  String get aboutRate => 'Rate SSHetu';

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
  String get aboutSupportSubject => 'SSHetu support';

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
  String get diagnosticsShareSubject => 'SSHetu diagnostics';

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
  String get terminalMoreActions => 'More';

  @override
  String get sessionLogStartEllipsis => 'Start logging…';

  @override
  String get sessionLogStop => 'Stop logging';

  @override
  String get sessionLogKeyword => 'log record save output';

  @override
  String sessionLogStartTitle(String session) {
    return 'Log $session';
  }

  @override
  String get sessionLogStartAction => 'Start logging';

  @override
  String get sessionLogFormat => 'Log format';

  @override
  String get sessionLogFormatPlain => 'Plain text';

  @override
  String get sessionLogFormatPlainHint =>
      'Readable text, without colours or control codes';

  @override
  String get sessionLogFormatRaw => 'Raw (with colours)';

  @override
  String get sessionLogFormatRawHint =>
      'Exactly as received; replay it with cat';

  @override
  String get sessionLogFormatAsciicast => 'asciicast (.cast)';

  @override
  String get sessionLogFormatAsciicastHint =>
      'A timed recording; play it with asciinema';

  @override
  String get sessionLogPrivacyNote =>
      'Everything the server prints is written to the file. What you type is not logged separately — the server echoes it back, so it appears only as shown on screen. Passwords typed at a prompt are not echoed, so they are not logged.';

  @override
  String sessionLogStarted(String file) {
    return 'Logging to $file';
  }

  @override
  String sessionLogSaved(String file) {
    return 'Log saved: $file';
  }

  @override
  String get sessionLogShare => 'Share';

  @override
  String get sessionLogFailed => 'Could not write the session log';

  @override
  String sessionLogIndicator(String file) {
    return 'Logging to $file';
  }

  @override
  String sessionLogLarge(String file) {
    return '$file is over 100 MB and still growing';
  }

  @override
  String get sessionLogMarkerDisconnected => 'connection lost';

  @override
  String get sessionLogMarkerReconnected => 'reconnected';

  @override
  String get sessionLogMarkerStopped => 'logging stopped';

  @override
  String get sessionLogMarkerTabClosed => 'tab closed';

  @override
  String get sessionLogFolder => 'Session log folder';

  @override
  String get sessionLogFolderNone =>
      'Not chosen — you are asked where to save each log';

  @override
  String get sessionLogFolderClear => 'Clear folder';

  @override
  String get sessionLogAlways => 'Always log new sessions';

  @override
  String get sessionLogAlwaysBody =>
      'Every new terminal tab writes its output to a log file without asking.';

  @override
  String get sessionLogAlwaysNeedsFolder =>
      'Choose a log folder first, so logs have somewhere to go without asking.';

  @override
  String get terminalPaste => 'Paste';

  @override
  String get terminalCopy => 'Copy';

  @override
  String get terminalNothingSelected =>
      'Nothing selected. Long-press the terminal to select text, then copy.';

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
  String get keysGenerate => 'Generate key';

  @override
  String get keysGenerateTitle => 'Generate a new key';

  @override
  String get keysGenerateBody =>
      'A new keypair, made on this device. The private half stays in this device\'s secure storage and never leaves it.';

  @override
  String get keysGenerateLabel => 'Name this key';

  @override
  String get keysGenerateDone =>
      'Add this line to the server\'s ~/.ssh/authorized_keys:';

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
  String get keysTypeLabel => 'Key type';

  @override
  String get keysTypeEd25519 => 'Ed25519 (recommended)';

  @override
  String get keysTypeEcdsaP256 => 'ECDSA P-256';

  @override
  String get keysTypeEcdsaP384 => 'ECDSA P-384';

  @override
  String get keysTypeRsa3072 => 'RSA 3072';

  @override
  String get keysTypeRsa4096 => 'RSA 4096';

  @override
  String get keysTypeHelp =>
      'Ed25519 works with every current server. Choose another only if a server or policy requires it.';

  @override
  String get keysPassphraseLabel => 'Passphrase (optional)';

  @override
  String get keysPassphraseHelp =>
      'Leave empty to rely on this device\'s lock. If set, you will be asked for it when connecting, and it cannot be recovered.';

  @override
  String get keysPassphraseRepeat => 'Repeat passphrase';

  @override
  String get keysPassphraseMismatch => 'The passphrases don\'t match.';

  @override
  String get keysGenerating => 'Generating…';

  @override
  String get keysGeneratingSlow =>
      'Generating an RSA key. This can take a few seconds.';

  @override
  String get keysGenerateFailed => 'The key could not be generated.';

  @override
  String get keysShare => 'Share public key';

  @override
  String get keysPaste => 'Paste key';

  @override
  String get paletteTitle => 'Command palette';

  @override
  String get paletteSearchHint => 'Search servers, tabs, snippets and actions';

  @override
  String get paletteOpenTooltip => 'Search everything';

  @override
  String get menuCommandPalette => 'Command Palette…';

  @override
  String paletteNoResults(String query) {
    return 'Nothing matches “$query”';
  }

  @override
  String get paletteNoResultsBody =>
      'Try fewer letters, or part of a hostname.';

  @override
  String get paletteEmptyTitle => 'Nothing to search yet';

  @override
  String get paletteEmptyBody =>
      'Add a server and it shows up here, with its tabs, tunnels and snippets.';

  @override
  String get paletteRecent => 'Recent';

  @override
  String get paletteKeyHint =>
      '↑↓ to move · Enter to run · Tab for other actions · Esc to close';

  @override
  String get paletteCategoryHost => 'Server';

  @override
  String get paletteCategorySession => 'Tab';

  @override
  String get paletteCategorySnippet => 'Snippet';

  @override
  String get paletteCategoryTunnel => 'Tunnel';

  @override
  String get paletteCategorySetting => 'Settings';

  @override
  String get paletteCategoryAction => 'Action';

  @override
  String get paletteSwitchTo => 'Switch to';

  @override
  String get paletteOpenFiles => 'Open files';

  @override
  String get paletteTunnelStart => 'Start tunnel';

  @override
  String get paletteTunnelStop => 'Stop tunnel';

  @override
  String get paletteToggleTheme => 'Switch between light and dark theme';

  @override
  String paletteGoTo(String destination) {
    return 'Go to $destination';
  }

  @override
  String paletteSettingsSection(String section) {
    return 'Settings › $section';
  }

  @override
  String get keysPasteTitle => 'Paste a private key';

  @override
  String get keysPasteBody =>
      'An OpenSSH or PEM private key. It is stored in this device\'s secure storage and never logged.';

  @override
  String get keysPasteField => 'Private key';

  @override
  String get keysPasteCheck => 'Check key';

  @override
  String get keysPasteSave => 'Save key';

  @override
  String get keysPastePassphrase => 'Passphrase';

  @override
  String get keysPastePassphraseHelp =>
      'Used only to read the key now. It is not saved: you will be asked for it when connecting.';

  @override
  String get keysPasteEmpty => 'Paste a private key first.';

  @override
  String get keysPastePublicKey =>
      'That is a public key. Paste the private key instead: the file without .pub, starting with -----BEGIN.';

  @override
  String get keysPasteNotAKey => 'That doesn\'t look like a private key.';

  @override
  String get keysPasteUnsupported =>
      'This key format can\'t be used. OpenSSH, PEM RSA and PEM EC keys are supported; convert others with ssh-keygen or PuTTYgen.';

  @override
  String get keysPasteNeedsPassphrase =>
      'This key is protected. Enter its passphrase to read it.';

  @override
  String get keysPasteWrongPassphrase =>
      'That passphrase doesn\'t open this key.';

  @override
  String get keysPasteDamaged =>
      'This key is damaged or incomplete. Copy it again, including the BEGIN and END lines.';

  @override
  String keysPasteDuplicate(String label) {
    return 'You already have this key, as $label.';
  }

  @override
  String get keysPasteSaveFailed =>
      'The key could not be saved to this device\'s secure storage.';

  @override
  String get keysPublicKeyHeading => 'Public key';

  @override
  String get keysFingerprintHeading => 'Fingerprint';

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
      'This device has no ~/.ssh to scan. Choose a private key file instead — AirDrop or copy one across, then pick it here.';

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
  String get tunnelsEmptyBody =>
      'Add a forward to reach a port on a host through its SSH connection.';

  @override
  String get importChooseFolder => 'Choose folder';

  @override
  String get importChooseFolderConfirm => 'Read this folder';

  @override
  String get importChooseFolderBody =>
      'Choose your .ssh folder so it can be read. Nothing in it is changed.';

  @override
  String get hostsNoMatches => 'No hosts match';

  @override
  String get sessionsEmptyPickHost =>
      'Pick a host on the left to open a session.';

  @override
  String get sessionsGoToHosts => 'Choose a host';

  @override
  String get terminalSessionEnded => 'Session ended';

  @override
  String get timeNow => 'now';

  @override
  String reachabilityUp(int ms) {
    return 'Reachable · $ms ms';
  }

  @override
  String reachabilityDown(String reason) {
    return 'Unreachable ($reason)';
  }

  @override
  String get reachabilityTimedOut => 'timed out';

  @override
  String get reachabilityRefused => 'connection refused';

  @override
  String get reachabilityUnresolved => 'address not found';

  @override
  String get reachabilityNoRoute => 'no route to host';

  @override
  String get reachabilityUnknown => 'Not checked yet';

  @override
  String get reachabilitySession => 'Connected · a session is open';

  @override
  String get reachabilityCheckedNow => 'Checked just now';

  @override
  String reachabilityCheckedMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Checked $count min ago',
      one: 'Checked 1 min ago',
    );
    return '$_temp0';
  }

  @override
  String reachabilityCheckedHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Checked $count hours ago',
      one: 'Checked 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get settingsReachability => 'Check whether hosts are reachable';

  @override
  String get settingsReachabilityBody =>
      'While the host list is on screen, briefly opens a connection to each server\'s port — never signs in. Slower checks are kinder to servers with connection limits.';

  @override
  String get settingsReachabilityOff => 'Off';

  @override
  String get settingsReachability30s => '30 s';

  @override
  String get settingsReachability1m => '1 min';

  @override
  String get settingsReachability5m => '5 min';

  @override
  String get hostEditorIdentityAny => 'Any of my keys';

  @override
  String get hostEditorAuthKeyHint =>
      'Offers your keys, and falls back to a password if the server refuses them — the same as ssh.';

  @override
  String get hostEditorAuthPasswordHint => 'Never offers a key to this host.';

  @override
  String get hostEditorAuthPasswordOnly => 'Password only';

  @override
  String get secretUseKeyInstead => 'Use a key instead';

  @override
  String get secretPickKey => 'Choose a key';

  @override
  String get secretPickKeyBody =>
      'This key is saved on the host, so it is used from now on.';

  @override
  String get secretNoKeys => 'You have no keys yet.';

  @override
  String get interactiveAuthTitle => 'Server sign-in';

  @override
  String get interactiveAuthSubmit => 'Submit';

  @override
  String get interactiveAuthAnswerLabel => 'Answer';

  @override
  String get knownHostsTitle => 'Trusted host keys';

  @override
  String get knownHostsSubtitle => 'Server identities this device has accepted';

  @override
  String get knownHostsEmptyTitle => 'No trusted hosts yet';

  @override
  String get knownHostsEmptyBody =>
      'A server\'s key is recorded here the first time you accept it.';

  @override
  String get knownHostsForget => 'Forget this key';

  @override
  String get knownHostsForgetConfirm => 'Forget this host key?';

  @override
  String get knownHostsForgetBody =>
      'The next connection to this address will ask you to trust its key again. Do this only if you know the server was genuinely rebuilt — a key that changed on its own is how an interception looks.';

  @override
  String knownHostsTrustedOn(String date) {
    return 'Trusted $date';
  }

  @override
  String get knownHostsCopied => 'Fingerprint copied';

  @override
  String get knownHostsImport => 'Import from known_hosts';

  @override
  String get knownHostsImportTitle => 'Import trusted host keys';

  @override
  String knownHostsImportFrom(String path) {
    return 'From $path';
  }

  @override
  String knownHostsImportNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new keys to trust',
      one: '1 new key to trust',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportNewHashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count of them have hashed names. They are stored as they are and recognised when you connect to those hosts, but cannot be listed by name.',
      one: '1 of them has a hashed name. It is stored as it is and recognised when you connect to that host, but it cannot be listed by name.',
    );
    return '$_temp0';
  }

  @override
  String get knownHostsImportNothing => 'Nothing new to import';

  @override
  String knownHostsImportAlready(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count already trusted',
      one: '1 already trusted',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hosts conflict with keys you already trust',
      one: '1 host conflicts with a key you already trust',
    );
    return '$_temp0';
  }

  @override
  String get knownHostsImportConflictsBody =>
      'These are left unchanged. If a server really was rebuilt, forget its old key here first, then import again.';

  @override
  String knownHostsImportTrusted(String key) {
    return 'Trusted: $key';
  }

  @override
  String knownHostsImportInFile(String key) {
    return 'In the file: $key';
  }

  @override
  String get knownHostsImportSkipped => 'Not imported';

  @override
  String knownHostsImportRevoked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count @revoked lines — this app pins keys it trusts and keeps no list of keys to refuse',
      one: '1 @revoked line — this app pins keys it trusts and keeps no list of keys to refuse',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportCertAuthority(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count @cert-authority lines — host certificates are not supported',
      one: '1 @cert-authority line — host certificates are not supported',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportWildcards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count wildcard or negated names — a trusted key is for one exact host',
      one: '1 wildcard or negated name — a trusted key is for one exact host',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportUnsupported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keys of a type this app cannot verify',
      one: '1 key of a type this app cannot verify',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportMalformed(int count, String lines) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unreadable lines ($lines)',
      one: '1 unreadable line ($lines)',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportAlternates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count extra keys for hosts — one key is kept per host, the type a connection uses first',
      one: '1 extra key for a host — one key is kept per host, the type a connection uses first',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count keys',
      one: 'Import 1 key',
      zero: 'Import',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trusted $count host keys',
      one: 'Trusted 1 host key',
    );
    return '$_temp0';
  }

  @override
  String get knownHostsImportReadFailed => 'Could not read that file';

  @override
  String get knownHostsImportTooLarge =>
      'That file is too large to be a known_hosts file';

  @override
  String get knownHostsHashedTitle => 'Hashed host name (imported)';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsAppLock => 'Require unlock for saved credentials';

  @override
  String get settingsAppLockBody =>
      'Confirm it\'s you with a fingerprint, your face or the device PIN before a saved password or key is used.';

  @override
  String get settingsAppLockUnavailable =>
      'Set up a screen lock, fingerprint, face or Windows Hello on this device first.';

  @override
  String get settingsAppLockCancelled =>
      'Not confirmed, so the setting was not changed.';

  @override
  String get settingsAppLockLockedOut =>
      'Too many attempts. Unlock your device, then try again.';

  @override
  String get settingsAppLockFailed =>
      'This device could not confirm it\'s you.';

  @override
  String get appLockEnableReason =>
      'Confirm it\'s you to lock your saved credentials';

  @override
  String get appLockDisableReason =>
      'Confirm it\'s you to stop locking your saved credentials';

  @override
  String get appLockUnlockReason => 'Unlock your saved SSH credentials';

  @override
  String get filesTitle => 'Files';

  @override
  String get filesRemote => 'Remote';

  @override
  String get filesLocal => 'This device';

  @override
  String get filesEmptyTitle => 'This folder is empty';

  @override
  String get filesNoSessionTitle => 'No session to browse';

  @override
  String get filesNoSessionBody =>
      'Open a terminal first, then open its files from there.';

  @override
  String get filesDownload => 'Download';

  @override
  String get filesUpload => 'Upload';

  @override
  String get filesUploadTitle => 'Upload to the server';

  @override
  String get filesUploadAs => 'Save on the server as';

  @override
  String get filesUploadFromDevice => 'Upload from device…';

  @override
  String get filesSaveToDevice => 'Save to device…';

  @override
  String filesUploadedName(String name) {
    return 'Uploaded $name';
  }

  @override
  String get filesDelete => 'Delete';

  @override
  String get filesDeleteConfirm => 'Delete this?';

  @override
  String filesDeleteBody(String name) {
    return '$name is deleted permanently. This cannot be undone.';
  }

  @override
  String get filesTransferFailed => 'Failed';

  @override
  String get tunnelsAdd => 'Add tunnel';

  @override
  String get tunnelsHostMissing => 'That host no longer exists';

  @override
  String get tunnelsStartFailed => 'Could not start the tunnel';

  @override
  String get tunnelsDeleteConfirm => 'Delete this tunnel?';

  @override
  String get tunnelsDeleteBody => 'Stops it if it is running.';

  @override
  String get tunnelsStart => 'Start';

  @override
  String get tunnelsStop => 'Stop';

  @override
  String get tunnelsEdit => 'Edit';

  @override
  String get tunnelsDelete => 'Delete';

  @override
  String get tunnelStatusStopped => 'Stopped';

  @override
  String get tunnelStatusStarting => 'Starting…';

  @override
  String get tunnelStatusRunning => 'Running';

  @override
  String get tunnelStatusFailed => 'Failed';

  @override
  String get tunnelFarEndListening => 'Target listening';

  @override
  String get tunnelFarEndNotListening => 'Nothing listening on target';

  @override
  String get tunnelFarEndHelp =>
      'Checked from the server every 30 seconds while this screen is open.';

  @override
  String get portsTitle => 'Ports on this server';

  @override
  String get portsTab => 'Ports';

  @override
  String get portsLoading => 'Looking for listening ports…';

  @override
  String get portsEmpty => 'No listening ports found';

  @override
  String get portsEmptyBody =>
      'Start a server on this machine and it shows up here within a few seconds. System services such as SSH and DNS are left out.';

  @override
  String get portsOfflineBody =>
      'The list resumes when the session reconnects.';

  @override
  String portsError(String error) {
    return 'Could not list this server\'s ports: $error';
  }

  @override
  String get portsLoopbackOnly => 'This server only';

  @override
  String get portsAllInterfaces => 'All interfaces';

  @override
  String get portsForward => 'Forward';

  @override
  String portsForwardTooltip(int port) {
    return 'Forward a port on this device to port $port on the server';
  }

  @override
  String portsForwardFailed(int port, String error) {
    return 'Could not forward port $port: $error';
  }

  @override
  String get portsForwardActions => 'Forward actions';

  @override
  String get portsOpenInBrowser => 'Open in browser';

  @override
  String get portsCopyAddress => 'Copy address';

  @override
  String portsCopied(String address) {
    return 'Copied $address';
  }

  @override
  String get portsSaveAsTunnel => 'Save as tunnel';

  @override
  String portsSavedAsTunnel(String label) {
    return 'Saved as tunnel \"$label\"';
  }

  @override
  String get portsStopForward => 'Stop forward';

  @override
  String get settingsStartTunnelsAtLaunch =>
      'Start auto-start tunnels when SSHetu opens';

  @override
  String get settingsStartTunnelsAtLaunchBody =>
      'Tunnels set to start automatically connect as soon as the app opens, instead of waiting for a terminal to their server. SSHetu then connects to those servers without asking first.';

  @override
  String tunnelActiveConnections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String get tunnelNotLoopbackShort => 'Exposed to the network';

  @override
  String get tunnelEditorNew => 'New tunnel';

  @override
  String get tunnelEditorEdit => 'Edit tunnel';

  @override
  String get tunnelEditorHost => 'Host';

  @override
  String get tunnelEditorLabel => 'Name';

  @override
  String get tunnelEditorLabelHint => 'What you call it — \"prod database\"';

  @override
  String get tunnelEditorKind => 'Type';

  @override
  String get tunnelKindLocal => 'Local';

  @override
  String get tunnelKindRemote => 'Remote';

  @override
  String get tunnelKindSocks => 'Dynamic';

  @override
  String get tunnelKindLocalHint =>
      'Forwards a port on this device to the target, through the SSH connection — the same as ssh -L.';

  @override
  String get tunnelKindRemoteHint =>
      'Asks the server to forward one of its ports back to a target reachable from here — the same as ssh -R.';

  @override
  String get tunnelKindSocksHint =>
      'A local SOCKS5 proxy with no fixed target — the same as ssh -D. Point an app\'s proxy setting at it.';

  @override
  String get tunnelEditorListen => 'Listen';

  @override
  String get tunnelEditorListenHost => 'Address';

  @override
  String get tunnelEditorPort => 'Port';

  @override
  String get tunnelEditorNotLoopback =>
      'Binding anything other than 127.0.0.1 exposes this forward to the whole network.';

  @override
  String get tunnelEditorTarget => 'Target';

  @override
  String get tunnelEditorTargetHost => 'Host';

  @override
  String get tunnelEditorTargetHostHint => 'example.com or 10.0.0.4';

  @override
  String get tunnelEditorAutoStart => 'Start automatically';

  @override
  String get tunnelEditorAutoStartHint =>
      'Starts when you open a terminal to this host.';

  @override
  String get tunnelWhat => 'What do you want to do?';

  @override
  String get tunnelLocalPlain => 'Reach something on the server';

  @override
  String get tunnelLocalPlainBody =>
      'A database or web app running on the server becomes available on this device.';

  @override
  String get tunnelRemotePlain => 'Let the server reach this device';

  @override
  String get tunnelRemotePlainBody =>
      'Something running on this device becomes available on the server.';

  @override
  String get tunnelSocksPlain => 'Send traffic through the server';

  @override
  String get tunnelSocksPlainBody =>
      'A SOCKS proxy on this device, so apps pointed at it browse as if from the server.';

  @override
  String get tunnelPortHere => 'Port on this device';

  @override
  String get tunnelPortThere => 'Port on the server';

  @override
  String get tunnelServiceThere => 'Which service on the server';

  @override
  String get tunnelServiceHere => 'Which service on this device';

  @override
  String get tunnelAddressField => 'Address';

  @override
  String get tunnelPortField => 'Port';

  @override
  String tunnelPreviewLocal(String listen, String target, String server) {
    return 'Open $listen on this device and you reach $target on $server.';
  }

  @override
  String tunnelPreviewRemote(String listen, String server, String target) {
    return 'Open $listen on $server and it reaches $target on this device.';
  }

  @override
  String tunnelPreviewSocks(String listen, String server) {
    return 'Point an app at $listen as a SOCKS5 proxy and its traffic leaves from $server.';
  }

  @override
  String get tunnelAdvanced => 'Advanced';

  @override
  String get tunnelNameOptional => 'Name (optional)';

  @override
  String get tunnelNameHint => 'Left blank, it is named after the ports';

  @override
  String get tunnelBindHere => 'Listen address on this device';

  @override
  String get tunnelBindThere => 'Listen address on the server';

  @override
  String get tunnelPreviewServerFallback => 'the server';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionPaste => 'Paste';

  @override
  String get actionSelectAll => 'Select all';

  @override
  String get actionClear => 'Clear scrollback';

  @override
  String get sessionDisconnect => 'Disconnect';

  @override
  String get sessionCloseOthers => 'Close other tabs';

  @override
  String get filesTransferCancelled => 'Cancelled';

  @override
  String get filesPathEdit => 'Edit path';

  @override
  String get filesPathHint => 'Enter an absolute path';

  @override
  String get filesPathNotAbsolute =>
      'Enter an absolute path, starting with / or ~';

  @override
  String get filesPathNotFound => 'No such path';

  @override
  String get filesPathNotADirectory => 'That is a file, not a folder';

  @override
  String get filesPathOutsideSandbox =>
      'Outside the app\'s storage on this device';

  @override
  String get filesPathFailed => 'Could not check that path';

  @override
  String get filesPermissionDeniedTitle => 'Permission denied';

  @override
  String filesPermissionDeniedBody(String path) {
    return 'You don\'t have access to $path.';
  }

  @override
  String get filesNotFoundTitle => 'Not found';

  @override
  String filesNotFoundBody(String path) {
    return '$path no longer exists.';
  }

  @override
  String get filesSandboxNotice =>
      'Limited to this app\'s own storage on this device — neither iOS nor Android lets an app browse the rest of the filesystem without extra permissions this app does not request.';

  @override
  String get filesChmod => 'Change permissions';

  @override
  String get filesChmodOwner => 'Owner';

  @override
  String get filesChmodGroup => 'Group';

  @override
  String get filesChmodOther => 'Other';

  @override
  String get filesChmodRead => 'Read';

  @override
  String get filesChmodWrite => 'Write';

  @override
  String get filesChmodExecute => 'Execute';

  @override
  String get filesChmodOctalLabel => 'Octal';

  @override
  String get filesChmodOctalInvalid => 'Enter 1-4 octal digits, 0-7 each';

  @override
  String get filesChmodApply => 'Apply';

  @override
  String get filesShowHidden => 'Show hidden files';

  @override
  String get filesHideHidden => 'Hide hidden files';

  @override
  String get filesSortBy => 'Sort by';

  @override
  String get filesSortName => 'Name';

  @override
  String get filesSortSize => 'Size';

  @override
  String get filesSortModified => 'Modified';

  @override
  String get filesSelect => 'Select';

  @override
  String get filesSelectAll => 'Select all';

  @override
  String filesSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get filesDownloadSelected => 'Download selected';

  @override
  String get filesUploadSelected => 'Upload selected';

  @override
  String get filesDeleteSelected => 'Delete selected';

  @override
  String filesDeleteSelectedBody(int count) {
    return '$count items are deleted permanently. This cannot be undone.';
  }

  @override
  String get filesRename => 'Rename';

  @override
  String get filesNewFolder => 'New folder';

  @override
  String get filesCreate => 'Create';

  @override
  String get filesNameLabel => 'Name';

  @override
  String get filesNameEmpty => 'Enter a name';

  @override
  String get filesNameSeparator =>
      'A name cannot contain a path separator such as /';

  @override
  String get filesNameReserved =>
      '“.” and “..” are reserved and cannot be used as names';

  @override
  String filesNameExists(String name) {
    return 'Something called $name is already here';
  }

  @override
  String get filesActionFailed =>
      'That did not work. Details are in Settings → Diagnostics.';

  @override
  String get filesConflictTitle => 'Some files are already there';

  @override
  String filesConflictBody(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files in $name already exist at the destination.',
      one: '1 file in $name already exists at the destination.',
    );
    return '$_temp0 The choice applies to all of them.';
  }

  @override
  String get filesConflictOverwrite => 'Overwrite';

  @override
  String get filesConflictSkip => 'Skip existing';

  @override
  String get filesEdit => 'Edit';

  @override
  String filesDropUpload(String folder) {
    return 'Drop to upload to $folder';
  }

  @override
  String filesDropDownload(String folder) {
    return 'Drop to download to $folder';
  }

  @override
  String filesDragCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get editorRevert => 'Revert to saved';

  @override
  String editorSaveTooltip(String keys) {
    return 'Save ($keys)';
  }

  @override
  String get editorUnsaved => 'Unsaved changes';

  @override
  String editorSaved(String name) {
    return 'Saved $name';
  }

  @override
  String editorReloaded(String name) {
    return 'Reloaded $name from the server';
  }

  @override
  String get editorUtf8 => 'UTF-8';

  @override
  String get editorUtf8Bom => 'UTF-8 with BOM';

  @override
  String get editorLf => 'LF';

  @override
  String get editorCrlf => 'CRLF';

  @override
  String get editorMixedEndings => 'Mixed line endings, kept as they are';

  @override
  String get editorTooLargeTitle => 'Too large to edit here';

  @override
  String editorTooLargeBody(String name, String limit) {
    return '$name is larger than $limit. Download it and open it in an editor on this device instead.';
  }

  @override
  String get editorBinaryTitle => 'Not a text file';

  @override
  String editorBinaryBody(String name) {
    return '$name contains binary data, so it cannot be edited as text.';
  }

  @override
  String get editorNotUtf8Title => 'Not UTF-8 text';

  @override
  String editorNotUtf8Body(String name) {
    return '$name is not valid UTF-8. Saving it from here could change characters you never touched, so it is not opened.';
  }

  @override
  String get editorNotAFileTitle => 'Not a file';

  @override
  String editorNotAFileBody(String name) {
    return '$name is a folder.';
  }

  @override
  String get editorLoadFailedTitle => 'Could not open the file';

  @override
  String get editorConflictTitle => 'Changed on the server';

  @override
  String editorConflictBody(String name) {
    return '$name was changed on the server after you opened it. Overwrite that change with yours, reload the server\'s version and lose your edits, or cancel and decide later.';
  }

  @override
  String get editorConflictOverwrite => 'Overwrite';

  @override
  String get editorConflictReload => 'Reload';

  @override
  String get editorDiscardTitle => 'Discard unsaved changes?';

  @override
  String editorDiscardBody(String name) {
    return 'Your edits to $name have not been saved.';
  }

  @override
  String get editorDiscard => 'Discard';

  @override
  String get filesFolderPreparing => 'Preparing…';

  @override
  String filesFolderProgress(int done, int total) {
    return '$done of $total files';
  }

  @override
  String filesFolderTransferred(int done, int total) {
    return '$done of $total files transferred';
  }

  @override
  String filesFolderSkipped(int count) {
    return '$count skipped (links or too deep)';
  }

  @override
  String filesFolderExistingSkipped(int count) {
    return '$count already there';
  }

  @override
  String get importPickKeyFile => 'Choose a key file';

  @override
  String importKeyAdded(String label) {
    return 'Added $label';
  }

  @override
  String get importNotAKey => 'That file is not a private key.';

  @override
  String get importNoteBodyMobile =>
      'Add a private key from a file on this device.';

  @override
  String get transferTitle => 'Move to another device';

  @override
  String get transferBody =>
      'Send your servers, keys and tunnels straight to another device on the same network. Nothing goes through a server, and nothing is stored anywhere but the two devices.';

  @override
  String get transferSend => 'Send to a device';

  @override
  String get transferReceive => 'Receive from a device';

  @override
  String get transferSendTitle => 'Scan this on the other device';

  @override
  String get transferSendBody =>
      'Open SSHetu on the other device, choose Receive, and point it at this code.';

  @override
  String get transferIncludeSecrets => 'Include keys and passwords';

  @override
  String get transferIncludeSecretsBody =>
      'Sends the private keys and saved passwords themselves, not just the list of servers.';

  @override
  String get transferWaiting => 'Waiting for the other device…';

  @override
  String transferSentTo(String device) {
    return 'Sent to $device';
  }

  @override
  String get transferReceiveTitle => 'Scan the other device\'s code';

  @override
  String get transferReceiveBody =>
      'On the device that has your servers, choose Move to another device, then Send.';

  @override
  String get transferPasteInstead => 'Paste a code instead';

  @override
  String get transferPasteHint => 'sshetu://transfer/…';

  @override
  String get transferOfferTitle => 'Accept this transfer?';

  @override
  String transferOfferFrom(String device) {
    return 'From $device';
  }

  @override
  String transferOfferHosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers',
      one: '1 server',
      zero: 'No servers',
    );
    return '$_temp0';
  }

  @override
  String transferOfferKeys(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keys',
      one: '1 key',
      zero: 'No keys',
    );
    return '$_temp0';
  }

  @override
  String transferOfferTunnels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tunnels',
      one: '1 tunnel',
      zero: 'No tunnels',
    );
    return '$_temp0';
  }

  @override
  String transferOfferTrusted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trusted host keys',
      one: '1 trusted host key',
      zero: 'No trusted host keys',
    );
    return '$_temp0';
  }

  @override
  String get transferOfferSecrets =>
      'Includes private keys and saved passwords';

  @override
  String get transferOfferNoSecrets => 'No keys or passwords included';

  @override
  String get transferOfferReplaces =>
      'Anything already on this device with the same name is replaced.';

  @override
  String get transferAccept => 'Accept';

  @override
  String transferReceived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servers received',
      one: '1 server received',
    );
    return '$_temp0';
  }

  @override
  String get transferScanAgain => 'Scan again';

  @override
  String get transferCameraDenied =>
      'SSHetu needs the camera to scan a code. You can paste the code as text instead.';

  @override
  String get transferCopyCode => 'Copy code';

  @override
  String get transferCodeCopied => 'Code copied. Paste it on the other device.';

  @override
  String get transferScanCode => 'Scan a code';

  @override
  String get menuFile => 'File';

  @override
  String get menuView => 'View';

  @override
  String get menuSession => 'Session';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuNewHost => 'New Server…';

  @override
  String get menuImport => 'Import from OpenSSH…';

  @override
  String get menuGenerateKey => 'Generate Key…';

  @override
  String get menuSendToDevice => 'Send to a Device…';

  @override
  String get menuReceiveFromDevice => 'Receive from a Device…';

  @override
  String get menuCloseSession => 'Close Session';

  @override
  String get menuNextSession => 'Next Session';

  @override
  String get menuPreviousSession => 'Previous Session';

  @override
  String get menuSplitRight => 'Split Right';

  @override
  String get menuSplitDown => 'Split Down';

  @override
  String get menuClosePane => 'Close Pane';

  @override
  String get menuNextPane => 'Next Pane';

  @override
  String get menuPreviousPane => 'Previous Pane';

  @override
  String get menuMaximizePane => 'Maximize Pane';

  @override
  String get menuTypeInAllPanes => 'Type in All Panes';

  @override
  String get menuStopTypingInAllPanes => 'Stop Typing in All Panes';

  @override
  String get paneSplitRight => 'Split right';

  @override
  String get paneSplitDown => 'Split down';

  @override
  String get paneClose => 'Close pane';

  @override
  String get paneMaximize => 'Maximize pane';

  @override
  String get paneRestore => 'Restore pane';

  @override
  String get paneTypeInAll => 'Type in all panes';

  @override
  String get paneStopTypingInAll => 'Stop typing in all panes';

  @override
  String paneBroadcastBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Typing in all panes · $count other panes receive this',
      one: 'Typing in all panes · 1 other pane receives this',
    );
    return '$_temp0';
  }

  @override
  String get paneBroadcastReceiving => 'Receives what is typed in any pane';

  @override
  String get paneBroadcastExcluded => 'Left out of typing in all panes';

  @override
  String get paneBroadcastExclude => 'Leave this pane out';

  @override
  String get paneBroadcastInclude => 'Include this pane';

  @override
  String get paneBroadcastStop => 'Stop';

  @override
  String get paneSwitcherLabel => 'Panes in this tab';

  @override
  String paneCount(int count) {
    return '$count panes';
  }

  @override
  String get menuHosts => 'Servers';

  @override
  String get menuKeys => 'Keys';

  @override
  String get menuTunnels => 'Tunnels';

  @override
  String get menuSnippets => 'Snippets';

  @override
  String get menuSnippetsEllipsis => 'Snippets…';

  @override
  String get navSnippets => 'Snippets';

  @override
  String get snippetsAdd => 'New snippet';

  @override
  String get snippetsSearch => 'Search snippets';

  @override
  String get snippetsEmptyTitle => 'No snippets yet';

  @override
  String snippetsEmptyBody(String example) {
    return 'Save commands you type often, then insert or run them in any session. Use $example for a value to fill in each time.';
  }

  @override
  String get snippetsNoMatch => 'No snippets match';

  @override
  String get snippetsEdit => 'Edit';

  @override
  String get snippetsDelete => 'Delete';

  @override
  String get snippetsMore => 'More';

  @override
  String get snippetsDeleteConfirm => 'Delete this snippet?';

  @override
  String get snippetsNoSession =>
      'Open a session first — a snippet needs somewhere to go.';

  @override
  String get snippetCopy => 'Copy command';

  @override
  String get snippetCopied => 'Command copied';

  @override
  String get snippetEditorNew => 'New snippet';

  @override
  String get snippetEditorEdit => 'Edit snippet';

  @override
  String get snippetEditorLabel => 'Name';

  @override
  String get snippetEditorLabelHint => 'Restart nginx';

  @override
  String get snippetEditorBody => 'Command';

  @override
  String snippetEditorBodyHint(String example) {
    return 'For example: $example';
  }

  @override
  String get snippetEditorDescription => 'Description (optional)';

  @override
  String get snippetEditorTags => 'Tags';

  @override
  String snippetEditorVariablesHint(
    String ask,
    String prefilled,
    String builtins,
  ) {
    return '$ask asks for a value when used, $prefilled prefills it. $builtins come from the session.';
  }

  @override
  String snippetEditorAsks(String names) {
    return 'Asks for: $names';
  }

  @override
  String snippetEditorFills(String names) {
    return 'Fills in: $names';
  }

  @override
  String snippetPickerTitle(String session) {
    return 'Snippets · $session';
  }

  @override
  String get snippetPickerManage => 'Manage snippets';

  @override
  String get snippetInsert => 'Insert';

  @override
  String get snippetRun => 'Run';

  @override
  String get snippetRunOn => 'Run on…';

  @override
  String get snippetRunOnTitle => 'Run on which sessions?';

  @override
  String get snippetRunOnAll => 'All connected sessions';

  @override
  String get snippetRunOnNotConnected => 'Not connected';

  @override
  String snippetRunOnConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Run in $count sessions',
      one: 'Run in 1 session',
    );
    return '$_temp0';
  }

  @override
  String get snippetVariablesTitle => 'Fill in the snippet';

  @override
  String get snippetVariablesPreview => 'Will type';

  @override
  String get snippetNotConnected =>
      'This session isn\'t connected, so nothing was typed.';

  @override
  String get snippetEmpty => 'That snippet has nothing to type.';

  @override
  String get snippetMultilineInsertRefused =>
      'This shell would run each line as it arrived, so the snippet was not inserted. Use Run instead.';

  @override
  String snippetRanIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ran in $count sessions',
      one: 'Ran in 1 session',
    );
    return '$_temp0';
  }

  @override
  String snippetRanInSome(int sent, int total) {
    return 'Ran in $sent of $total sessions — the rest weren\'t connected';
  }

  @override
  String transferOfferSnippets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count snippets',
      one: '1 snippet',
      zero: 'No snippets',
    );
    return '$_temp0';
  }

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuTrustedHostKeys => 'Trusted Host Keys';

  @override
  String get menuDiagnostics => 'Diagnostics';

  @override
  String get transferFirewallNote =>
      'macOS may ask whether SSHetu can accept incoming connections. Allow it — the other device connects to this one, so without it nothing can reach you.';

  @override
  String get transferFirewallNoteWindows =>
      'Windows may ask whether SSHetu can communicate on this network. Allow it on your private network — the other device connects to this one, so without it nothing can reach you.';

  @override
  String get transferStepPermission =>
      'Asking macOS for permission to accept connections…';

  @override
  String get transferStepBinding => 'Opening a port…';

  @override
  String get transferCancel => 'Cancel';

  @override
  String get transferNotStarted => 'Sharing hasn\'t started.';

  @override
  String get menuCloseTab => 'Close Tab';

  @override
  String get menuWindow => 'Window';

  @override
  String get menuMinimize => 'Minimize';

  @override
  String get menuZoom => 'Zoom';

  @override
  String get menuFullScreen => 'Enter Full Screen';

  @override
  String get menuBringAllToFront => 'Bring All to Front';

  @override
  String get menuHide => 'Hide SSHetu';

  @override
  String get menuHideOthers => 'Hide Others';

  @override
  String get menuShowAll => 'Show All';

  @override
  String get menuServices => 'Services';

  @override
  String get menuQuit => 'Quit SSHetu';

  @override
  String get menuAboutApp => 'About SSHetu';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupBody =>
      'An encrypted copy of your servers, keys and tunnels, saved as a file you keep.';

  @override
  String get backupExport => 'Save a backup…';

  @override
  String get backupImport => 'Restore from a backup…';

  @override
  String get backupPassphrase => 'Passphrase';

  @override
  String get backupPassphraseConfirm => 'Repeat passphrase';

  @override
  String get backupPassphraseHelp =>
      'This passphrase is the only thing protecting the file. It cannot be recovered — if you lose it, the backup is gone.';

  @override
  String get backupPassphraseMismatch => 'The two passphrases are different.';

  @override
  String backupPassphraseTooShort(int count) {
    return 'Use at least $count characters.';
  }

  @override
  String get backupStrengthWeak => 'Weak — easy to guess';

  @override
  String get backupStrengthFair => 'Fair';

  @override
  String get backupStrengthStrong => 'Strong';

  @override
  String get backupIncludeSecrets => 'Include keys and passwords';

  @override
  String get backupIncludeSecretsBody =>
      'Without these the backup restores your servers but you will have to supply keys again.';

  @override
  String get backupWorking => 'Encrypting…';

  @override
  String backupSaved(String path) {
    return 'Backup saved to $path';
  }

  @override
  String get backupShared => 'Backup ready to save.';

  @override
  String get backupSaveAnother => 'Save another';

  @override
  String get backupRestoreTitle => 'Restore a backup';

  @override
  String get backupRestoreBody =>
      'Choose a backup file, then enter the passphrase it was saved with.';

  @override
  String get backupChooseFile => 'Choose file…';

  @override
  String get backupOpening => 'Opening…';

  @override
  String get backupOpen => 'Open backup';

  @override
  String get backupRestore => 'Restore';

  @override
  String get backupRestoreWarning =>
      'Restoring replaces anything on this device with the same name. It cannot be undone.';

  @override
  String backupContents(
    int hosts,
    int identities,
    int tunnels,
    int knownHosts,
  ) {
    return '$hosts servers, $identities keys, $tunnels tunnels, $knownHosts trusted host keys';
  }

  @override
  String get backupWithSecrets => 'Includes private keys and saved passwords.';

  @override
  String get backupWithoutSecrets =>
      'Does not include private keys or passwords.';

  @override
  String backupWrittenOn(String date, String version) {
    return 'Saved $date by SSHetu $version';
  }

  @override
  String get backupRestored => 'Restored.';

  @override
  String get menuSaveBackup => 'Save a Backup…';

  @override
  String get menuRestoreBackup => 'Restore from a Backup…';

  @override
  String get keySetupTitle => 'Use a key instead of a password';

  @override
  String get keySetupBody =>
      'Adds a public key to this server\'s authorized_keys, checks it really logs you in, and then stops saving your password here.';

  @override
  String get keySetupChooseKey => 'Which key?';

  @override
  String get keySetupGenerate => 'Generate a new key';

  @override
  String get keySetupStart => 'Set up';

  @override
  String get keySetupInstalling => 'Adding the key to the server…';

  @override
  String get keySetupVerifying => 'Logging in with the key…';

  @override
  String get keySetupFinishing => 'Tidying up…';

  @override
  String get keySetupRollingBack => 'Putting the server back…';

  @override
  String keySetupDone(String host, String key) {
    return 'Done — $host now uses $key, and the saved password has been removed.';
  }

  @override
  String get keySetupAlreadyPresent => 'That key was already on the server.';

  @override
  String get keySetupServerNote =>
      'This does not change the server\'s own settings. It still accepts passwords from other clients — only this app stops using one.';

  @override
  String get keySetupNoKeys =>
      'You have no keys yet. Generate one to continue.';

  @override
  String get menuUseKeyInstead => 'Use a Key Instead of a Password…';

  @override
  String get keySetupUnavailable =>
      'Connect to this server first — the key is installed over the session you already have.';

  @override
  String get secretNotErased =>
      'Removed from SSHetu, but the system keychain would not erase the stored secret.';

  @override
  String get diagnosticsCopyOne => 'Copy this error';

  @override
  String get diagnosticsRemoveOne => 'Remove this error';

  @override
  String get diagnosticsCopied => 'Copied.';

  @override
  String get diagnosticsRemoved => 'Removed.';

  @override
  String get settingsDefaultKey => 'Default key';

  @override
  String get settingsDefaultKeyBody =>
      'New servers start with this key. You can change it per server.';

  @override
  String get settingsDefaultKeyNone => 'No default';

  @override
  String get hostEditorConnection => 'Server';

  @override
  String get hostEditorConnectionHint => 'root@192.168.1.10';

  @override
  String get hostEditorConnectionHelp =>
      'Paste an address or a whole ssh command — user, host and port are read from it.';

  @override
  String get hostEditorConnectionInvalid =>
      'That does not look like an address SSHetu can reach.';

  @override
  String get hostEditorIdentityFileIgnored =>
      'The -i path was ignored. SSHetu uses the keys it holds; choose one under Advanced options.';

  @override
  String get hostsNewGroup => 'New group';

  @override
  String get hostsShowNotes => 'Notes';

  @override
  String get hostsTagFilterClear => 'Clear tag filter';

  @override
  String get hostGroupName => 'Group name';

  @override
  String get hostGroupCreate => 'Create';

  @override
  String get hostGroupRename => 'Rename group';

  @override
  String get hostGroupRenameAction => 'Rename';

  @override
  String get hostGroupDelete => 'Delete group';

  @override
  String hostGroupDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get hostGroupDeleteBody =>
      'The group is removed. Its hosts are kept and move to Ungrouped.';

  @override
  String get hostGroupUngrouped => 'Ungrouped';

  @override
  String get hostGroupEmpty =>
      'No hosts in this group yet. Choose it in a host\'s editor.';

  @override
  String hostGroupCollapse(String name) {
    return 'Collapse $name';
  }

  @override
  String hostGroupExpand(String name) {
    return 'Expand $name';
  }

  @override
  String get hostEditorOrganise => 'Organise';

  @override
  String get hostEditorGroup => 'Group';

  @override
  String get hostEditorGroupNone => 'No group';

  @override
  String get hostEditorGroupNew => 'New group…';

  @override
  String get hostEditorTags => 'Tags';

  @override
  String get hostEditorTagsHint => 'Type a tag, then Enter or a comma';

  @override
  String get hostEditorTagAdd => 'Add tag';

  @override
  String get hostEditorNotes => 'Notes';

  @override
  String get hostEditorNotesHint =>
      'Anything worth remembering about this server';

  @override
  String get hostEditorKeepalive => 'Keepalive interval';

  @override
  String get hostEditorKeepaliveSuffix => 'seconds';

  @override
  String get hostEditorKeepaliveHelp =>
      '0 turns keepalives off. A shorter interval keeps mobile connections from being dropped while idle.';

  @override
  String get hostEditorKeepaliveInvalid => '0–3600';

  @override
  String get hostEditorFontSize => 'Terminal font size';

  @override
  String hostEditorFontSizeDefault(String size) {
    return 'Use the app default ($size)';
  }

  @override
  String get hostEditorFontSizeHelp =>
      'Zooming in the terminal changes the app default, not this host.';

  @override
  String get terminalFind => 'Find';

  @override
  String get menuFind => 'Find…';

  @override
  String get terminalFindHint => 'Find in scrollback';

  @override
  String terminalFindCount(int current, int total) {
    return '$current of $total';
  }

  @override
  String terminalFindCountCapped(int current, int total) {
    return '$current of $total+';
  }

  @override
  String get terminalFindNoMatches => 'No matches';

  @override
  String get terminalFindInvalidPattern => 'Invalid pattern';

  @override
  String get terminalFindCaseSensitive => 'Match case';

  @override
  String get terminalFindRegex => 'Regular expression';

  @override
  String get terminalFindOlder => 'Older match (Enter)';

  @override
  String get terminalFindNewer => 'Newer match (Shift+Enter)';

  @override
  String get terminalFindClose => 'Close (Esc)';

  @override
  String get terminalOpenLink => 'Open link';

  @override
  String get terminalCopyLink => 'Copy link';

  @override
  String get terminalLinkSheetTitle => 'Open this link?';

  @override
  String get terminalLinkRefused =>
      'SSHetu only opens http, https and mailto links.';

  @override
  String get terminalLinkOpenFailed => 'Could not open the link.';

  @override
  String get terminalLinkCopied => 'Link copied';

  @override
  String get pasteConfirmTitle => 'Paste and run?';

  @override
  String pasteConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'commands',
      one: 'a command',
    );
    return 'This text contains a line break, so pasting it will run $_temp0 at a shell prompt.';
  }

  @override
  String pasteConfirmLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String pasteConfirmMoreLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '…and $count more lines',
      one: '…and 1 more line',
    );
    return '$_temp0';
  }

  @override
  String pasteHiddenRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden characters removed',
      one: '1 hidden character removed',
    );
    return '$_temp0';
  }

  @override
  String get pasteDontAskAgain => 'Don\'t ask again';

  @override
  String get pasteConfirmAction => 'Paste';

  @override
  String get settingsTerminal => 'Terminal';

  @override
  String get settingsConfirmPaste => 'Confirm multi-line paste';

  @override
  String get settingsConfirmPasteBody =>
      'Ask before pasting text with a line break, which would run commands.';

  @override
  String get settingsKeepAlive => 'Keep connections alive in the background';

  @override
  String get settingsKeepAliveBody =>
      'Shows a notification while sessions or tunnels are open, so Android does not close them when you switch apps.';

  @override
  String get keepAliveChannelName => 'Active connections';

  @override
  String get keepAliveTitle => 'Connections open';

  @override
  String keepAliveSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String keepAliveTunnels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tunnels',
      one: '1 tunnel',
    );
    return '$_temp0';
  }

  @override
  String keepAliveSummaryBoth(String sessions, String tunnels) {
    return '$sessions, $tunnels active';
  }

  @override
  String keepAliveSummaryOne(String what) {
    return '$what active';
  }

  @override
  String get keepAliveDisconnectAll => 'Disconnect all';

  @override
  String get settingsKeepSessions => 'Keep sessions running on the server';

  @override
  String get settingsKeepSessionsBody =>
      'Runs each tab inside tmux when the server has it, so a dropped connection picks up where it left off. Closing the tab ends it.';

  @override
  String get terminalNoticeConnectionLost => '[connection lost — reconnecting]';

  @override
  String get terminalNoticeSessionEnded => '[session ended]';

  @override
  String get terminalNoticeSessionClosed => '[session closed]';

  @override
  String get terminalNoticeReconnected => '[reconnected]';

  @override
  String get terminalNoticeTmuxUnavailable =>
      '[tmux is not installed on this server, so this session will not survive a dropped connection]';

  @override
  String terminalReconnectWaiting(int seconds, int attempt) {
    return 'Connection lost — reconnecting in $seconds s (attempt $attempt)';
  }

  @override
  String terminalReconnectWaitingShort(int seconds) {
    return 'Reconnecting in $seconds s';
  }

  @override
  String get terminalReconnecting => 'Reconnecting…';

  @override
  String get terminalRetryNow => 'Retry now';

  @override
  String get terminalStopReconnecting => 'Stop';

  @override
  String get settingsTerminalAppearance => 'Terminal appearance';

  @override
  String get settingsTerminalTheme => 'Terminal theme';

  @override
  String get terminalThemeAdaptive => 'Follows light and dark';

  @override
  String get terminalThemeFixedDark => 'Dark';

  @override
  String get terminalThemeFixedLight => 'Light';

  @override
  String get terminalPreviewUser => 'you@server';

  @override
  String get terminalPreviewCommand => 'ls';

  @override
  String get terminalPreviewDirectory => 'docs';

  @override
  String get terminalPreviewFile => 'notes.txt';

  @override
  String get terminalPreviewScript => 'deploy.sh';

  @override
  String get terminalPreviewError => 'error: permission denied';

  @override
  String get settingsTerminalFont => 'Terminal font';

  @override
  String get terminalFontSystem => 'System monospace';

  @override
  String get settingsCursorShape => 'Cursor';

  @override
  String get cursorShapeBlock => 'Block';

  @override
  String get cursorShapeUnderline => 'Underline';

  @override
  String get cursorShapeBar => 'Bar';

  @override
  String get settingsCursorBlink => 'Blinking cursor';

  @override
  String get settingsCursorBlinkBody =>
      'Programs such as vim can still change the cursor while they run.';

  @override
  String get settingsScrollback => 'Scrollback';

  @override
  String settingsScrollbackValue(int lines) {
    final intl.NumberFormat linesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String linesString = linesNumberFormat.format(lines);

    return '$linesString lines · applies to new tabs';
  }

  @override
  String scrollbackLinesOption(int lines) {
    final intl.NumberFormat linesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String linesString = linesNumberFormat.format(lines);

    return '$linesString lines';
  }

  @override
  String get hostEditorTerminalTheme => 'Terminal theme';

  @override
  String hostEditorTerminalThemeDefault(String name) {
    return 'Use default ($name)';
  }

  @override
  String get terminalNoticeTmuxSessionGone =>
      '[the session kept on the server has ended, so this is a new shell]';

  @override
  String get hostsRunningSessions => 'Running sessions…';

  @override
  String get sessionRunningSessions => 'Sessions on this server…';

  @override
  String get serverInfoTitle => 'Server info';

  @override
  String get serverInfoShow => 'Server info';

  @override
  String get serverInfoHide => 'Hide server info';

  @override
  String get serverInfoClose => 'Close server info';

  @override
  String get serverInfoOverview => 'Overview';

  @override
  String get serverInfoProcesses => 'Processes';

  @override
  String get serverInfoHostname => 'Hostname';

  @override
  String get serverInfoSystem => 'System';

  @override
  String get serverInfoKernel => 'Kernel';

  @override
  String get serverInfoUptime => 'Uptime';

  @override
  String get serverInfoLoad => 'Load';

  @override
  String get serverInfoCpu => 'CPU';

  @override
  String serverInfoCpuCores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cores',
      one: '1 core',
    );
    return '$_temp0';
  }

  @override
  String serverInfoCpuHistory(int count) {
    return 'CPU usage over the last $count readings';
  }

  @override
  String get serverInfoMemory => 'Memory';

  @override
  String get serverInfoSwap => 'Swap';

  @override
  String get serverInfoNoSwap => 'No swap';

  @override
  String serverInfoUsedOfTotal(String used, String total) {
    return '$used of $total';
  }

  @override
  String get serverInfoFilesystems => 'Filesystems';

  @override
  String get serverInfoNetwork => 'Network';

  @override
  String get serverInfoNetDown => 'Down';

  @override
  String get serverInfoNetUp => 'Up';

  @override
  String serverInfoProcessCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processes',
      one: '1 process',
    );
    return '$_temp0';
  }

  @override
  String get serverInfoLimited => 'Limited information on this system';

  @override
  String get serverInfoLimitedBody =>
      'This server does not report CPU, memory or load in a way SSHetu can read, so only the basics are shown.';

  @override
  String get serverInfoOffline => 'Not connected';

  @override
  String get serverInfoOfflineBody =>
      'Figures resume when the session reconnects.';

  @override
  String serverInfoError(String error) {
    return 'Could not read this server\'s figures: $error';
  }

  @override
  String get serverInfoNoSession => 'No session selected';

  @override
  String get serverInfoNoSessionBody =>
      'Open a terminal to see details of the server behind it.';

  @override
  String get serverInfoWaiting => 'Measuring…';

  @override
  String get processesFilter => 'Filter by name, user or PID';

  @override
  String get processesSortBy => 'Sort by';

  @override
  String get processesSortCpu => 'CPU';

  @override
  String get processesSortMem => 'Memory';

  @override
  String get processesSortPid => 'PID';

  @override
  String get processesRefresh => 'Refresh';

  @override
  String get processesEmpty => 'No processes match';

  @override
  String get processesNoUsage =>
      'This server\'s ps does not report CPU or memory use.';

  @override
  String get processesKill => 'Kill (SIGTERM)';

  @override
  String get processesForceKill => 'Force kill (SIGKILL)';

  @override
  String processesActions(String name) {
    return 'Actions for $name';
  }

  @override
  String processesKillTitle(String name) {
    return 'Stop $name?';
  }

  @override
  String processesKillBody(String name, int pid) {
    return 'Sends SIGTERM to $name (PID $pid). It is asked to exit and can clean up first.';
  }

  @override
  String processesForceKillTitle(String name) {
    return 'Force kill $name?';
  }

  @override
  String processesForceKillBody(String name, int pid) {
    return 'Sends SIGKILL to $name (PID $pid). It stops immediately, without a chance to save anything.';
  }

  @override
  String get processesKillConfirm => 'Kill';

  @override
  String get processesForceKillConfirm => 'Force kill';

  @override
  String processesSignalSent(String signal, String name, int pid) {
    return 'Sent $signal to $name (PID $pid)';
  }

  @override
  String processesSignalFailed(String name, int pid, String error) {
    return 'Could not signal $name (PID $pid): $error';
  }

  @override
  String processesLoadFailed(String error) {
    return 'Could not list processes: $error';
  }

  @override
  String osFamilyName(String family) {
    String _temp0 = intl.Intl.selectLogic(family, {
      'ubuntu': 'Ubuntu',
      'debian': 'Debian',
      'fedora': 'Fedora',
      'rhel': 'Red Hat family',
      'arch': 'Arch Linux',
      'alpine': 'Alpine Linux',
      'opensuse': 'openSUSE',
      'freebsd': 'FreeBSD',
      'macos': 'macOS',
      'windows': 'Windows',
      'linux': 'Linux',
      'other': 'Unknown system',
    });
    return '$_temp0';
  }

  @override
  String runningSessionsTitle(String host) {
    return 'Sessions on $host';
  }

  @override
  String get runningSessionsIntro =>
      'Shells SSHetu keeps running on this server — from this device and your others. Attach one to pick up where you left off: start something on your desktop, carry on from your phone.';

  @override
  String get runningSessionsSharedNote =>
      'Attaching a session that is open on another device shares it: both screens show the same shell, and either can type. Closing a tab attached from here leaves the session running — end it here when you are done.';

  @override
  String get runningSessionsRefresh => 'Refresh';

  @override
  String get runningSessionsError =>
      'Could not list the sessions on this server';

  @override
  String get runningSessionsNoTmux =>
      'tmux is not installed on this server, so SSHetu cannot keep sessions running on it.';

  @override
  String get runningSessionsEmpty =>
      'No SSHetu sessions are running on this server';

  @override
  String get runningSessionsEmptyBody =>
      'Tabs opened with “Keep sessions running on the server” turned on appear here, from any of your devices, for as long as they run.';

  @override
  String get runningSessionsThisDevice => 'This device';

  @override
  String runningSessionsOtherDevice(String id) {
    return 'Another device ($id)';
  }

  @override
  String get runningSessionsOlder => 'An earlier SSHetu version';

  @override
  String runningSessionsStarted(String age) {
    return 'started $age ago';
  }

  @override
  String runningSessionsActive(String age) {
    return 'active $age ago';
  }

  @override
  String runningSessionsRunning(String command) {
    return 'running $command';
  }

  @override
  String get runningSessionsAttached => 'Attached elsewhere';

  @override
  String get runningSessionsOpenHere => 'Open here';

  @override
  String get runningSessionsAttach => 'Attach';

  @override
  String get runningSessionsShow => 'Show';

  @override
  String get runningSessionsEnd => 'End';

  @override
  String get runningSessionsEndTitle => 'End this session?';

  @override
  String runningSessionsEndBody(String host) {
    return 'Everything running in it on $host stops, on every device attached to it. This cannot be undone.';
  }

  @override
  String runningSessionsEndFailed(String error) {
    return 'Could not end the session: $error';
  }

  @override
  String runningSessionsAttachFailed(String error) {
    return 'Could not attach: $error';
  }

  @override
  String get settingsReopenTabs => 'Reopen tabs on launch';

  @override
  String get settingsReopenTabsBody =>
      'Brings back the terminal tabs that were open when SSHetu last closed, reattaching the sessions kept on the server.';

  @override
  String get settingsReopenTabsAsk => 'Ask';

  @override
  String get settingsReopenTabsAlways => 'Always';

  @override
  String get settingsReopenTabsNever => 'Never';

  @override
  String get restoreTabsTitle => 'Reopen your tabs?';

  @override
  String restoreTabsBody(int count, String hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count terminal tabs were open when SSHetu last closed: $hosts.',
      one: '1 terminal tab was open when SSHetu last closed: $hosts.',
    );
    return '$_temp0';
  }

  @override
  String get restoreTabsRemember => 'Don’t ask again';

  @override
  String get restoreTabsNotNow => 'Not now';

  @override
  String get restoreTabsReopen => 'Reopen';

  @override
  String get hostEditorEnv => 'Environment';

  @override
  String get hostEditorEnvHelp =>
      'Set in every new shell on this host, exactly as typed. A session already kept on the server keeps the values it started with.';

  @override
  String get hostEditorEnvName => 'Name';

  @override
  String get hostEditorEnvValue => 'Value';

  @override
  String get hostEditorEnvAdd => 'Add variable';

  @override
  String get hostEditorEnvRemove => 'Remove variable';

  @override
  String get hostEditorEnvMissingName => 'Give it a name';

  @override
  String get hostEditorEnvInvalidName =>
      'Letters, digits and _ only, not starting with a digit';

  @override
  String get hostEditorEnvDuplicateName => 'Already set above';

  @override
  String get hostEditorEnvInvalidValue => 'Cannot contain a line break';

  @override
  String get hostEditorForwardAgent => 'Forward SSH agent';

  @override
  String get hostEditorForwardAgentHelp =>
      'Lets this server use your keys to sign in elsewhere while you\'re connected. Only enable it for servers you trust. If the server has AllowAgentForwarding disabled, the connection will fail.';

  @override
  String get exportJsonTitle => 'Export as JSON (no secrets)';

  @override
  String get exportJsonSubtitle =>
      'A readable file of your hosts, tunnels and snippets for other tools. Keys and passwords are left out.';

  @override
  String get exportJsonBody =>
      'Hosts, groups, tunnels, snippets, public keys and trusted host keys, in a documented format any tool can read. Importing it back into SSHetu loses nothing.';

  @override
  String get exportJsonNoSecrets =>
      'Private keys, key passphrases and saved passwords are never included. To keep those too, save an encrypted backup instead.';

  @override
  String get exportJsonBackupInstead => 'Encrypted backup…';

  @override
  String get exportJsonAction => 'Export';

  @override
  String exportJsonSaved(String path) {
    return 'Exported to $path';
  }

  @override
  String get exportJsonShared => 'Export ready to save.';

  @override
  String exportJsonFailed(String error) {
    return 'Could not export: $error';
  }

  @override
  String get importJsonTitle => 'Import from JSON';

  @override
  String get importJsonSubtitle =>
      'An SSHetu JSON export. You see what will change before anything is written.';

  @override
  String get importJsonNotJson => 'This file is not JSON.';

  @override
  String get importJsonNotExport =>
      'This is not an SSHetu export. Choose a file saved with Export as JSON.';

  @override
  String importJsonNewer(int version, int supported) {
    return 'This export was written by a newer version of SSHetu (format version $version; this build reads up to version $supported). Update SSHetu and try again.';
  }

  @override
  String get importJsonInvalidVersion =>
      'This export has no valid format version, so it cannot be read.';

  @override
  String importJsonMalformed(String field) {
    return 'This export is damaged or was edited incorrectly: $field is missing or invalid.';
  }

  @override
  String get importJsonReadFailed => 'Could not read that file.';

  @override
  String importJsonFrom(String name) {
    return 'From $name';
  }

  @override
  String importJsonHostsNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new hosts',
      one: '1 new host',
    );
    return '$_temp0';
  }

  @override
  String importJsonHostsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved hosts updated (same id)',
      one: '1 saved host updated (same id)',
    );
    return '$_temp0';
  }

  @override
  String importJsonHostsUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hosts already up to date',
      one: '1 host already up to date',
    );
    return '$_temp0';
  }

  @override
  String importJsonConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hosts match saved ones by address',
      one: '1 host matches a saved one by address',
    );
    return '$_temp0';
  }

  @override
  String get importJsonConflictsBody =>
      'Same user, host and port as a saved host, but a different id — probably the same server saved on two devices.';

  @override
  String get importJsonMerge => 'Merge';

  @override
  String get importJsonAddAsNew => 'Add as new';

  @override
  String get importJsonMergeHelp =>
      'The saved host takes the file\'s settings. Its tunnels and saved password stay attached.';

  @override
  String get importJsonAddAsNewHelp =>
      'The saved host is left as it is, and the file\'s is added as a second host.';

  @override
  String importJsonConflictRow(String incoming, String existing) {
    return '$incoming → saved as $existing';
  }

  @override
  String get importJsonAlso => 'Also in this file';

  @override
  String importJsonGroups(int added, int updated) {
    return 'Groups: $added new, $updated updated';
  }

  @override
  String importJsonTunnels(int count) {
    return 'Tunnels: $count to add or update';
  }

  @override
  String importJsonSnippets(int added, int updated) {
    return 'Snippets: $added new, $updated updated';
  }

  @override
  String importJsonKnownHosts(int count) {
    return 'Trusted host keys: $count new';
  }

  @override
  String importJsonKnownHostsConflicting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count trusted host keys in the file differ from the ones saved here and are left out. An import never replaces a trust decision.',
      one: '1 trusted host key in the file differs from the one saved here and is left out. An import never replaces a trust decision.',
    );
    return '$_temp0';
  }

  @override
  String get importJsonMissingKeysTitle => 'Keys to bring over';

  @override
  String get importJsonMissingKeysBody =>
      'An export never contains private keys. These hosts are imported without their key until you bring it to this device — with an encrypted backup, Send to a device, or by pasting it under Keys — and choose it in the host.';

  @override
  String importJsonMissingKeyHosts(String hosts) {
    return 'Used by: $hosts';
  }

  @override
  String get importJsonNothing =>
      'Everything in this file is already on this device.';

  @override
  String get importJsonAction => 'Import';

  @override
  String importJsonDone(int hosts, int tunnels, int snippets) {
    return 'Imported $hosts hosts, $tunnels tunnels and $snippets snippets';
  }

  @override
  String get puttyImportTitle => 'Import from PuTTY';

  @override
  String get puttyImportSubtitleWindows =>
      'Saved sessions from PuTTY on this PC, or a .reg file';

  @override
  String get puttyImportSubtitleFile =>
      'From a .reg file of PuTTY sessions exported on Windows';

  @override
  String get puttyImportFile => 'Import PuTTY .reg file';

  @override
  String get puttyChooseFile => 'Choose .reg file…';

  @override
  String get puttyNoneFoundTitle => 'No PuTTY sessions found';

  @override
  String get puttyNoneFoundBody =>
      'This Windows account has no saved PuTTY sessions. You can choose a .reg file instead: on the PC that has them, export the key HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions with regedit.';

  @override
  String get puttyNoneInFile => 'That file holds no PuTTY sessions.';

  @override
  String puttyReadFailed(String error) {
    return 'Could not read PuTTY sessions: $error';
  }

  @override
  String puttySkippedProtocol(String protocol) {
    return 'Not SSH ($protocol), so it is skipped';
  }

  @override
  String get puttySkippedNoHost => 'No host name, so it is skipped';

  @override
  String get puttyAlreadySaved => 'Already saved';

  @override
  String puttyNoUsername(String name) {
    return 'No user name saved; $name will be used';
  }

  @override
  String puttyPpk(String file) {
    return 'Key not imported: $file';
  }

  @override
  String puttyProxy(String proxy) {
    return 'Proxy not imported: $proxy';
  }

  @override
  String puttyForwards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count forwards become tunnels, off until you review them',
      one: '1 forward becomes a tunnel, off until you review it',
    );
    return '$_temp0';
  }

  @override
  String puttyInvalidForwards(String list) {
    return 'Forwards not understood: $list';
  }

  @override
  String get puttyPpkTitle => 'PuTTY keys (.ppk) can\'t be used directly';

  @override
  String puttyPpkBody(String hosts) {
    return 'Convert each key with PuTTYgen: load the .ppk, then Conversions → Export OpenSSH key. Import the result under Keys and choose it in the host. Hosts that use a .ppk key: $hosts';
  }

  @override
  String puttyImportAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count hosts',
      one: 'Import 1 host',
      zero: 'Import',
    );
    return '$_temp0';
  }

  @override
  String puttyImportDone(int hosts, int tunnels) {
    return 'Imported $hosts hosts and $tunnels tunnels. Tunnels stay off until you review and start them.';
  }

  @override
  String get importMoreSources => 'More ways to import';

  @override
  String get hostEditorTmuxMode =>
      'Keep sessions running on this server (tmux)';

  @override
  String get hostEditorTmuxModeHelp =>
      'Runs each tab inside tmux, so a dropped connection picks up where it left off. Default follows the setting in Settings → Terminal.';

  @override
  String get hostEditorTmuxModeDefaultOn => 'Default (currently on)';

  @override
  String get hostEditorTmuxModeDefaultOff => 'Default (currently off)';

  @override
  String get hostEditorTmuxModeAlways => 'Always';

  @override
  String get hostEditorTmuxModeNever => 'Never';

  @override
  String tmuxInstallPrompt(String host) {
    return 'tmux isn\'t installed on $host, so this session won\'t survive a dropped connection. Install it?';
  }

  @override
  String get tmuxInstallCommandLabel => 'This command will run on the server:';

  @override
  String get tmuxInstallCommandLabelTerminal =>
      'This command will run in this terminal:';

  @override
  String get tmuxInstallPasswordNote =>
      'sudo will ask for your password in the terminal. SSHetu never sees it.';

  @override
  String get tmuxInstallAction => 'Install';

  @override
  String get tmuxInstallActionTerminal => 'Run in terminal';

  @override
  String get tmuxInstallNotNow => 'Not now';

  @override
  String get tmuxInstallNever => 'Never for this host';

  @override
  String tmuxInstallRunning(String host) {
    return 'Installing tmux on $host…';
  }

  @override
  String get tmuxInstallSucceeded =>
      'tmux is installed. Restart this session in tmux? The shell in this tab closes, and anything running in it stops.';

  @override
  String get tmuxInstallRestart => 'Restart in tmux';

  @override
  String get tmuxInstallLater => 'Later';

  @override
  String get tmuxInstallFailed => 'Installing tmux failed:';

  @override
  String get tmuxInstallFailedStaleLists =>
      'Installing tmux failed: the server\'s package lists are out of date. Update them and try again?';

  @override
  String get tmuxInstallUpdateAction => 'Update and install';

  @override
  String get tmuxInstallDismiss => 'Dismiss';

  @override
  String get tmuxInstallTyped =>
      'Enter your sudo password in the terminal. When the install finishes, restart this session in tmux — the shell in this tab closes, and anything running in it stops.';

  @override
  String tmuxInstallUnknownManager(String host) {
    return 'tmux isn\'t installed on $host, and SSHetu doesn\'t recognise its package manager. Install tmux with the server\'s own tools to keep sessions running.';
  }

  @override
  String tmuxInstallNoPrivilege(String host) {
    return 'tmux isn\'t installed on $host. Installing it needs root, and this account has no sudo. Ask the server\'s administrator to install tmux.';
  }

  @override
  String get terminalRestartInTmux => 'Restart in tmux';

  @override
  String get terminalNoticeRestartedInTmux => '[restarted in tmux]';

  @override
  String get tmuxRestartConfirmTitle => 'Restart this session in tmux?';

  @override
  String get tmuxRestartConfirmBody =>
      'The shell in this tab closes, and anything running in it stops. A new shell opens inside tmux, so it survives a dropped connection.';

  @override
  String get tmuxRestartConfirmAction => 'Restart';
}
