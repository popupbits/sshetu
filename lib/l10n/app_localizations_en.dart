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
  String get keysGenerate => 'Generate key';

  @override
  String get keysGenerateTitle => 'Generate a new key';

  @override
  String get keysGenerateBody =>
      'An Ed25519 keypair, made on this device. The private half stays in this device\'s secure storage and never leaves it.';

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
}
