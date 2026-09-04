import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The app name, shown in the title bar and the About screen
  ///
  /// In en, this message translates to:
  /// **'SSHetu'**
  String get appTitle;

  /// No description provided for @navHosts.
  ///
  /// In en, this message translates to:
  /// **'Hosts'**
  String get navHosts;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get navKeys;

  /// No description provided for @navTunnels.
  ///
  /// In en, this message translates to:
  /// **'Tunnels'**
  String get navTunnels;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get actionShow;

  /// No description provided for @actionHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get actionHide;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get comingSoon;

  /// No description provided for @comingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'This screen is a placeholder. Replace it with the real thing.'**
  String get comingSoonBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get settingsAccent;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageNepali.
  ///
  /// In en, this message translates to:
  /// **'Nepali'**
  String get languageNepali;

  /// No description provided for @settingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextSize;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// No description provided for @textSizeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get textSizeDefault;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// No description provided for @textSizeLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get textSizeLarger;

  /// No description provided for @accentIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get accentIndigo;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @accentForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get accentForest;

  /// No description provided for @accentAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get accentAmber;

  /// No description provided for @accentCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get accentCoral;

  /// No description provided for @accentRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get accentRose;

  /// No description provided for @accentMauve.
  ///
  /// In en, this message translates to:
  /// **'Mauve'**
  String get accentMauve;

  /// No description provided for @accentSlate.
  ///
  /// In en, this message translates to:
  /// **'Slate'**
  String get accentSlate;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutPrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What we collect, and what we don\'t'**
  String get aboutPrivacyPolicySubtitle;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutLicenses;

  /// No description provided for @aboutLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Third-party packages this app uses'**
  String get aboutLicensesSubtitle;

  /// No description provided for @aboutShare.
  ///
  /// In en, this message translates to:
  /// **'Share SSHetu'**
  String get aboutShare;

  /// No description provided for @aboutShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell someone who\'d find it useful'**
  String get aboutShareSubtitle;

  /// No description provided for @aboutShareMessage.
  ///
  /// In en, this message translates to:
  /// **'I\'ve been using SSHetu — you might like it too.'**
  String get aboutShareMessage;

  /// No description provided for @aboutRate.
  ///
  /// In en, this message translates to:
  /// **'Rate SSHetu'**
  String get aboutRate;

  /// No description provided for @aboutRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A rating genuinely helps'**
  String get aboutRateSubtitle;

  /// No description provided for @aboutMoreApps.
  ///
  /// In en, this message translates to:
  /// **'More apps'**
  String get aboutMoreApps;

  /// No description provided for @aboutMoreAppsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Other apps we make'**
  String get aboutMoreAppsSubtitle;

  /// No description provided for @aboutSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get aboutSupport;

  /// No description provided for @aboutSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **''**
  String get aboutSupportSubtitle;

  /// No description provided for @aboutSupportSubject.
  ///
  /// In en, this message translates to:
  /// **'SSHetu support'**
  String get aboutSupportSubject;

  /// No description provided for @errorCouldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {target}'**
  String errorCouldNotOpen(String target);

  /// No description provided for @updateReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Update downloaded'**
  String get updateReadyTitle;

  /// No description provided for @updateRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get updateRestart;

  /// No description provided for @updateStuck.
  ///
  /// In en, this message translates to:
  /// **'An update is waiting to finish'**
  String get updateStuck;

  /// No description provided for @updateOpenStore.
  ///
  /// In en, this message translates to:
  /// **'Open Play Store'**
  String get updateOpenStore;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recent error} other{{count} recent errors}}'**
  String settingsDiagnosticsBody(int count);

  /// No description provided for @settingsDiagnosticsNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing to report'**
  String get settingsDiagnosticsNone;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No errors recorded'**
  String get diagnosticsEmpty;

  /// No description provided for @diagnosticsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When something goes wrong, it is collected here so you can send us the details.'**
  String get diagnosticsEmptyBody;

  /// No description provided for @diagnosticsShare.
  ///
  /// In en, this message translates to:
  /// **'Share report'**
  String get diagnosticsShare;

  /// No description provided for @diagnosticsShareSubject.
  ///
  /// In en, this message translates to:
  /// **'SSHetu diagnostics'**
  String get diagnosticsShareSubject;

  /// No description provided for @diagnosticsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diagnosticsClear;

  /// No description provided for @diagnosticsClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all recorded errors?'**
  String get diagnosticsClearConfirm;

  /// No description provided for @diagnosticsSeenTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{seen once} other{seen {count} times}}'**
  String diagnosticsSeenTimes(int count);

  /// No description provided for @hostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hosts'**
  String get hostsTitle;

  /// No description provided for @hostsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No servers yet'**
  String get hostsEmptyTitle;

  /// No description provided for @hostsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a server, or import the ones already on this machine.'**
  String get hostsEmptyBody;

  /// No description provided for @hostsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add host'**
  String get hostsAdd;

  /// No description provided for @hostsImport.
  ///
  /// In en, this message translates to:
  /// **'Import from OpenSSH'**
  String get hostsImport;

  /// No description provided for @hostsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search hosts'**
  String get hostsSearch;

  /// No description provided for @hostsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get hostsConnect;

  /// No description provided for @hostsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get hostsEdit;

  /// No description provided for @hostsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get hostsDelete;

  /// No description provided for @hostsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this host?'**
  String get hostsDeleteConfirm;

  /// No description provided for @hostsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its saved password is destroyed. Keys and known-host entries are left alone.'**
  String get hostsDeleteBody;

  /// No description provided for @hostsNeverConnected.
  ///
  /// In en, this message translates to:
  /// **'Never connected'**
  String get hostsNeverConnected;

  /// No description provided for @hostEditorNew.
  ///
  /// In en, this message translates to:
  /// **'New host'**
  String get hostEditorNew;

  /// No description provided for @hostEditorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit host'**
  String get hostEditorEdit;

  /// No description provided for @hostEditorLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get hostEditorLabel;

  /// No description provided for @hostEditorLabelHint.
  ///
  /// In en, this message translates to:
  /// **'What you call it — \"build box\"'**
  String get hostEditorLabelHint;

  /// No description provided for @hostEditorHostname.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get hostEditorHostname;

  /// No description provided for @hostEditorHostnameHint.
  ///
  /// In en, this message translates to:
  /// **'example.com or 10.0.0.4'**
  String get hostEditorHostnameHint;

  /// No description provided for @hostEditorPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get hostEditorPort;

  /// No description provided for @hostEditorUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get hostEditorUsername;

  /// No description provided for @hostEditorAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get hostEditorAuth;

  /// No description provided for @hostEditorAuthKey.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get hostEditorAuthKey;

  /// No description provided for @hostEditorAuthPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get hostEditorAuthPassword;

  /// No description provided for @hostEditorIdentity.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get hostEditorIdentity;

  /// No description provided for @hostEditorIdentityNone.
  ///
  /// In en, this message translates to:
  /// **'No key selected'**
  String get hostEditorIdentityNone;

  /// No description provided for @hostEditorJump.
  ///
  /// In en, this message translates to:
  /// **'Connect through'**
  String get hostEditorJump;

  /// No description provided for @hostEditorJumpNone.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get hostEditorJumpNone;

  /// No description provided for @hostEditorAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get hostEditorAdvanced;

  /// No description provided for @hostEditorStartup.
  ///
  /// In en, this message translates to:
  /// **'Startup command'**
  String get hostEditorStartup;

  /// No description provided for @hostEditorStartupHint.
  ///
  /// In en, this message translates to:
  /// **'tmux new -A -s main'**
  String get hostEditorStartupHint;

  /// No description provided for @hostEditorLegacy.
  ///
  /// In en, this message translates to:
  /// **'Allow legacy algorithms'**
  String get hostEditorLegacy;

  /// No description provided for @hostEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get hostEditorSave;

  /// No description provided for @hostEditorRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get hostEditorRequired;

  /// No description provided for @hostEditorPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'1–65535'**
  String get hostEditorPortInvalid;

  /// No description provided for @terminalConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get terminalConnecting;

  /// No description provided for @terminalDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get terminalDisconnect;

  /// No description provided for @terminalReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get terminalReconnect;

  /// No description provided for @terminalCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get terminalCloseTab;

  /// No description provided for @terminalPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get terminalPaste;

  /// No description provided for @terminalCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get terminalCopy;

  /// No description provided for @sessionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No open sessions'**
  String get sessionsEmptyTitle;

  /// No description provided for @sessionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to a host and it appears here.'**
  String get sessionsEmptyBody;

  /// No description provided for @hostKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown host'**
  String get hostKeyTitle;

  /// No description provided for @hostKeyTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust and connect'**
  String get hostKeyTrust;

  /// No description provided for @hostKeyChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Host identity changed'**
  String get hostKeyChangedTitle;

  /// No description provided for @hostKeyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get hostKeyFingerprint;

  /// No description provided for @secretPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get secretPasswordTitle;

  /// No description provided for @secretPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Key passphrase'**
  String get secretPassphraseTitle;

  /// No description provided for @secretRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember on this device'**
  String get secretRemember;

  /// No description provided for @secretUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get secretUnlock;

  /// No description provided for @keysTitle.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get keysTitle;

  /// No description provided for @keysEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No keys yet'**
  String get keysEmptyTitle;

  /// No description provided for @keysEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import the keys already in your ~/.ssh, or paste one in.'**
  String get keysEmptyBody;

  /// No description provided for @keysImport.
  ///
  /// In en, this message translates to:
  /// **'Import keys'**
  String get keysImport;

  /// No description provided for @keysGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate key'**
  String get keysGenerate;

  /// No description provided for @keysGenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate a new key'**
  String get keysGenerateTitle;

  /// No description provided for @keysGenerateBody.
  ///
  /// In en, this message translates to:
  /// **'An Ed25519 keypair, made on this device. The private half stays in this device\'s secure storage and never leaves it.'**
  String get keysGenerateBody;

  /// No description provided for @keysGenerateLabel.
  ///
  /// In en, this message translates to:
  /// **'Name this key'**
  String get keysGenerateLabel;

  /// No description provided for @keysGenerateDone.
  ///
  /// In en, this message translates to:
  /// **'Add this line to the server\'s ~/.ssh/authorized_keys:'**
  String get keysGenerateDone;

  /// No description provided for @keysCopyPublic.
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get keysCopyPublic;

  /// No description provided for @keysCopied.
  ///
  /// In en, this message translates to:
  /// **'Public key copied'**
  String get keysCopied;

  /// No description provided for @keysEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Passphrase-protected'**
  String get keysEncrypted;

  /// No description provided for @keysDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete key'**
  String get keysDelete;

  /// No description provided for @keysDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this key?'**
  String get keysDeleteConfirm;

  /// No description provided for @keysDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The private key is destroyed on this device and cannot be recovered.'**
  String get keysDeleteBody;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from OpenSSH'**
  String get importTitle;

  /// No description provided for @importScanning.
  ///
  /// In en, this message translates to:
  /// **'Looking for an existing setup…'**
  String get importScanning;

  /// No description provided for @importFoundIn.
  ///
  /// In en, this message translates to:
  /// **'Found in {path}'**
  String importFoundIn(String path);

  /// No description provided for @importNothingTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get importNothingTitle;

  /// No description provided for @importNothingBody.
  ///
  /// In en, this message translates to:
  /// **'No ~/.ssh directory with hosts or keys was found on this device.'**
  String get importNothingBody;

  /// No description provided for @importUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available here'**
  String get importUnavailableTitle;

  /// No description provided for @importUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This device has no ~/.ssh to scan. Choose a private key file instead — AirDrop or copy one across, then pick it here.'**
  String get importUnavailableBody;

  /// No description provided for @importHostsSection.
  ///
  /// In en, this message translates to:
  /// **'Hosts'**
  String get importHostsSection;

  /// No description provided for @importKeysSection.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get importKeysSection;

  /// No description provided for @importSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get importSelectAll;

  /// No description provided for @importSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get importSelectNone;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import {count} items'**
  String importAction(int count);

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {hosts} hosts and {keys} keys'**
  String importDone(int hosts, int keys);

  /// No description provided for @importUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not imported: {options}'**
  String importUnsupported(String options);

  /// No description provided for @importRescan.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get importRescan;

  /// No description provided for @importNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get importNoteTitle;

  /// No description provided for @importNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Your ~/.ssh files are read, never changed.'**
  String get importNoteBody;

  /// No description provided for @tunnelsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No port forwards'**
  String get tunnelsEmptyTitle;

  /// No description provided for @tunnelsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a forward to reach a port on a host through its SSH connection.'**
  String get tunnelsEmptyBody;

  /// No description provided for @importChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get importChooseFolder;

  /// No description provided for @importChooseFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Read this folder'**
  String get importChooseFolderConfirm;

  /// No description provided for @importChooseFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Choose your .ssh folder so it can be read. Nothing in it is changed.'**
  String get importChooseFolderBody;

  /// No description provided for @hostsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No hosts match'**
  String get hostsNoMatches;

  /// No description provided for @sessionsEmptyPickHost.
  ///
  /// In en, this message translates to:
  /// **'Pick a host on the left to open a session.'**
  String get sessionsEmptyPickHost;

  /// No description provided for @sessionsGoToHosts.
  ///
  /// In en, this message translates to:
  /// **'Choose a host'**
  String get sessionsGoToHosts;

  /// No description provided for @terminalSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended'**
  String get terminalSessionEnded;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// No description provided for @hostEditorIdentityAny.
  ///
  /// In en, this message translates to:
  /// **'Any of my keys'**
  String get hostEditorIdentityAny;

  /// No description provided for @hostEditorAuthKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Offers your keys, and falls back to a password if the server refuses them — the same as ssh.'**
  String get hostEditorAuthKeyHint;

  /// No description provided for @hostEditorAuthPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Never offers a key to this host.'**
  String get hostEditorAuthPasswordHint;

  /// No description provided for @hostEditorAuthPasswordOnly.
  ///
  /// In en, this message translates to:
  /// **'Password only'**
  String get hostEditorAuthPasswordOnly;

  /// No description provided for @secretUseKeyInstead.
  ///
  /// In en, this message translates to:
  /// **'Use a key instead'**
  String get secretUseKeyInstead;

  /// No description provided for @secretPickKey.
  ///
  /// In en, this message translates to:
  /// **'Choose a key'**
  String get secretPickKey;

  /// No description provided for @secretPickKeyBody.
  ///
  /// In en, this message translates to:
  /// **'This key is saved on the host, so it is used from now on.'**
  String get secretPickKeyBody;

  /// No description provided for @secretNoKeys.
  ///
  /// In en, this message translates to:
  /// **'You have no keys yet.'**
  String get secretNoKeys;

  /// No description provided for @knownHostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trusted host keys'**
  String get knownHostsTitle;

  /// No description provided for @knownHostsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server identities this device has accepted'**
  String get knownHostsSubtitle;

  /// No description provided for @knownHostsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No trusted hosts yet'**
  String get knownHostsEmptyTitle;

  /// No description provided for @knownHostsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A server\'s key is recorded here the first time you accept it.'**
  String get knownHostsEmptyBody;

  /// No description provided for @knownHostsForget.
  ///
  /// In en, this message translates to:
  /// **'Forget this key'**
  String get knownHostsForget;

  /// No description provided for @knownHostsForgetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Forget this host key?'**
  String get knownHostsForgetConfirm;

  /// No description provided for @knownHostsForgetBody.
  ///
  /// In en, this message translates to:
  /// **'The next connection to this address will ask you to trust its key again. Do this only if you know the server was genuinely rebuilt — a key that changed on its own is how an interception looks.'**
  String get knownHostsForgetBody;

  /// No description provided for @knownHostsTrustedOn.
  ///
  /// In en, this message translates to:
  /// **'Trusted {date}'**
  String knownHostsTrustedOn(String date);

  /// No description provided for @knownHostsCopied.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint copied'**
  String get knownHostsCopied;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// No description provided for @filesRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get filesRemote;

  /// No description provided for @filesLocal.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get filesLocal;

  /// No description provided for @filesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get filesEmptyTitle;

  /// No description provided for @filesNoSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'No session to browse'**
  String get filesNoSessionTitle;

  /// No description provided for @filesNoSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Open a terminal first, then open its files from there.'**
  String get filesNoSessionBody;

  /// No description provided for @filesDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get filesDownload;

  /// No description provided for @filesUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get filesUpload;

  /// No description provided for @filesUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload to the server'**
  String get filesUploadTitle;

  /// Prefilled with the picker's name, which on Android may carry an extension it guessed rather than the one the file had.
  ///
  /// In en, this message translates to:
  /// **'Save on the server as'**
  String get filesUploadAs;

  /// Opens the system file picker to send a file to the server. The only way to upload from a phone, whose local pane cannot leave this app's storage.
  ///
  /// In en, this message translates to:
  /// **'Upload from device…'**
  String get filesUploadFromDevice;

  /// Downloads a remote file and hands it to the system share sheet, so it can be saved somewhere the user can actually reach.
  ///
  /// In en, this message translates to:
  /// **'Save to device…'**
  String get filesSaveToDevice;

  /// No description provided for @filesUploadedName.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {name}'**
  String filesUploadedName(String name);

  /// No description provided for @filesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get filesDelete;

  /// No description provided for @filesDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this?'**
  String get filesDeleteConfirm;

  /// No description provided for @filesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is deleted permanently. This cannot be undone.'**
  String filesDeleteBody(String name);

  /// No description provided for @filesTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get filesTransferFailed;

  /// No description provided for @tunnelsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add tunnel'**
  String get tunnelsAdd;

  /// No description provided for @tunnelsHostMissing.
  ///
  /// In en, this message translates to:
  /// **'That host no longer exists'**
  String get tunnelsHostMissing;

  /// No description provided for @tunnelsStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the tunnel'**
  String get tunnelsStartFailed;

  /// No description provided for @tunnelsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this tunnel?'**
  String get tunnelsDeleteConfirm;

  /// No description provided for @tunnelsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Stops it if it is running.'**
  String get tunnelsDeleteBody;

  /// No description provided for @tunnelsStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get tunnelsStart;

  /// No description provided for @tunnelsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get tunnelsStop;

  /// No description provided for @tunnelsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tunnelsEdit;

  /// No description provided for @tunnelsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tunnelsDelete;

  /// No description provided for @tunnelStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get tunnelStatusStopped;

  /// No description provided for @tunnelStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get tunnelStatusStarting;

  /// No description provided for @tunnelStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get tunnelStatusRunning;

  /// No description provided for @tunnelStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get tunnelStatusFailed;

  /// No description provided for @tunnelActiveConnections.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active} other{{count} active}}'**
  String tunnelActiveConnections(int count);

  /// No description provided for @tunnelNotLoopbackShort.
  ///
  /// In en, this message translates to:
  /// **'Exposed to the network'**
  String get tunnelNotLoopbackShort;

  /// No description provided for @tunnelEditorNew.
  ///
  /// In en, this message translates to:
  /// **'New tunnel'**
  String get tunnelEditorNew;

  /// No description provided for @tunnelEditorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit tunnel'**
  String get tunnelEditorEdit;

  /// No description provided for @tunnelEditorHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get tunnelEditorHost;

  /// No description provided for @tunnelEditorLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tunnelEditorLabel;

  /// No description provided for @tunnelEditorLabelHint.
  ///
  /// In en, this message translates to:
  /// **'What you call it — \"prod database\"'**
  String get tunnelEditorLabelHint;

  /// No description provided for @tunnelEditorKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get tunnelEditorKind;

  /// No description provided for @tunnelKindLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get tunnelKindLocal;

  /// No description provided for @tunnelKindRemote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get tunnelKindRemote;

  /// No description provided for @tunnelKindSocks.
  ///
  /// In en, this message translates to:
  /// **'Dynamic'**
  String get tunnelKindSocks;

  /// No description provided for @tunnelKindLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Forwards a port on this device to the target, through the SSH connection — the same as ssh -L.'**
  String get tunnelKindLocalHint;

  /// No description provided for @tunnelKindRemoteHint.
  ///
  /// In en, this message translates to:
  /// **'Asks the server to forward one of its ports back to a target reachable from here — the same as ssh -R.'**
  String get tunnelKindRemoteHint;

  /// No description provided for @tunnelKindSocksHint.
  ///
  /// In en, this message translates to:
  /// **'A local SOCKS5 proxy with no fixed target — the same as ssh -D. Point an app\'s proxy setting at it.'**
  String get tunnelKindSocksHint;

  /// No description provided for @tunnelEditorListen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get tunnelEditorListen;

  /// No description provided for @tunnelEditorListenHost.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get tunnelEditorListenHost;

  /// No description provided for @tunnelEditorPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get tunnelEditorPort;

  /// No description provided for @tunnelEditorNotLoopback.
  ///
  /// In en, this message translates to:
  /// **'Binding anything other than 127.0.0.1 exposes this forward to the whole network.'**
  String get tunnelEditorNotLoopback;

  /// No description provided for @tunnelEditorTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get tunnelEditorTarget;

  /// No description provided for @tunnelEditorTargetHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get tunnelEditorTargetHost;

  /// No description provided for @tunnelEditorTargetHostHint.
  ///
  /// In en, this message translates to:
  /// **'example.com or 10.0.0.4'**
  String get tunnelEditorTargetHostHint;

  /// No description provided for @tunnelEditorAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Start automatically'**
  String get tunnelEditorAutoStart;

  /// No description provided for @tunnelEditorAutoStartHint.
  ///
  /// In en, this message translates to:
  /// **'Starts when you open a terminal to this host.'**
  String get tunnelEditorAutoStartHint;

  /// No description provided for @tunnelWhat.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do?'**
  String get tunnelWhat;

  /// No description provided for @tunnelLocalPlain.
  ///
  /// In en, this message translates to:
  /// **'Reach something on the server'**
  String get tunnelLocalPlain;

  /// No description provided for @tunnelLocalPlainBody.
  ///
  /// In en, this message translates to:
  /// **'A database or web app running on the server becomes available on this device.'**
  String get tunnelLocalPlainBody;

  /// No description provided for @tunnelRemotePlain.
  ///
  /// In en, this message translates to:
  /// **'Let the server reach this device'**
  String get tunnelRemotePlain;

  /// No description provided for @tunnelRemotePlainBody.
  ///
  /// In en, this message translates to:
  /// **'Something running on this device becomes available on the server.'**
  String get tunnelRemotePlainBody;

  /// No description provided for @tunnelSocksPlain.
  ///
  /// In en, this message translates to:
  /// **'Send traffic through the server'**
  String get tunnelSocksPlain;

  /// No description provided for @tunnelSocksPlainBody.
  ///
  /// In en, this message translates to:
  /// **'A SOCKS proxy on this device, so apps pointed at it browse as if from the server.'**
  String get tunnelSocksPlainBody;

  /// No description provided for @tunnelPortHere.
  ///
  /// In en, this message translates to:
  /// **'Port on this device'**
  String get tunnelPortHere;

  /// No description provided for @tunnelPortThere.
  ///
  /// In en, this message translates to:
  /// **'Port on the server'**
  String get tunnelPortThere;

  /// No description provided for @tunnelServiceThere.
  ///
  /// In en, this message translates to:
  /// **'Which service on the server'**
  String get tunnelServiceThere;

  /// No description provided for @tunnelServiceHere.
  ///
  /// In en, this message translates to:
  /// **'Which service on this device'**
  String get tunnelServiceHere;

  /// No description provided for @tunnelAddressField.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get tunnelAddressField;

  /// No description provided for @tunnelPortField.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get tunnelPortField;

  /// No description provided for @tunnelPreviewLocal.
  ///
  /// In en, this message translates to:
  /// **'Open {listen} on this device and you reach {target} on {server}.'**
  String tunnelPreviewLocal(String listen, String target, String server);

  /// No description provided for @tunnelPreviewRemote.
  ///
  /// In en, this message translates to:
  /// **'Open {listen} on {server} and it reaches {target} on this device.'**
  String tunnelPreviewRemote(String listen, String server, String target);

  /// No description provided for @tunnelPreviewSocks.
  ///
  /// In en, this message translates to:
  /// **'Point an app at {listen} as a SOCKS5 proxy and its traffic leaves from {server}.'**
  String tunnelPreviewSocks(String listen, String server);

  /// No description provided for @tunnelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get tunnelAdvanced;

  /// No description provided for @tunnelNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get tunnelNameOptional;

  /// No description provided for @tunnelNameHint.
  ///
  /// In en, this message translates to:
  /// **'Left blank, it is named after the ports'**
  String get tunnelNameHint;

  /// No description provided for @tunnelBindHere.
  ///
  /// In en, this message translates to:
  /// **'Listen address on this device'**
  String get tunnelBindHere;

  /// No description provided for @tunnelBindThere.
  ///
  /// In en, this message translates to:
  /// **'Listen address on the server'**
  String get tunnelBindThere;

  /// No description provided for @tunnelPreviewServerFallback.
  ///
  /// In en, this message translates to:
  /// **'the server'**
  String get tunnelPreviewServerFallback;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get actionPaste;

  /// No description provided for @actionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get actionSelectAll;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear scrollback'**
  String get actionClear;

  /// No description provided for @sessionDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get sessionDisconnect;

  /// No description provided for @sessionCloseOthers.
  ///
  /// In en, this message translates to:
  /// **'Close other tabs'**
  String get sessionCloseOthers;

  /// No description provided for @filesTransferCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get filesTransferCancelled;

  /// No description provided for @filesPathEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit path'**
  String get filesPathEdit;

  /// No description provided for @filesPathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute path'**
  String get filesPathHint;

  /// No description provided for @filesPathNotAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute path, starting with / or ~'**
  String get filesPathNotAbsolute;

  /// No description provided for @filesPathNotFound.
  ///
  /// In en, this message translates to:
  /// **'No such path'**
  String get filesPathNotFound;

  /// No description provided for @filesPathNotADirectory.
  ///
  /// In en, this message translates to:
  /// **'That is a file, not a folder'**
  String get filesPathNotADirectory;

  /// No description provided for @filesPathOutsideSandbox.
  ///
  /// In en, this message translates to:
  /// **'Outside the app\'s storage on this device'**
  String get filesPathOutsideSandbox;

  /// No description provided for @filesPathFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check that path'**
  String get filesPathFailed;

  /// No description provided for @filesPermissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get filesPermissionDeniedTitle;

  /// No description provided for @filesPermissionDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to {path}.'**
  String filesPermissionDeniedBody(String path);

  /// No description provided for @filesNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get filesNotFoundTitle;

  /// No description provided for @filesNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'{path} no longer exists.'**
  String filesNotFoundBody(String path);

  /// No description provided for @filesSandboxNotice.
  ///
  /// In en, this message translates to:
  /// **'Limited to this app\'s own storage on this device — neither iOS nor Android lets an app browse the rest of the filesystem without extra permissions this app does not request.'**
  String get filesSandboxNotice;

  /// No description provided for @filesChmod.
  ///
  /// In en, this message translates to:
  /// **'Change permissions'**
  String get filesChmod;

  /// No description provided for @filesChmodOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get filesChmodOwner;

  /// No description provided for @filesChmodGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get filesChmodGroup;

  /// No description provided for @filesChmodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get filesChmodOther;

  /// No description provided for @filesChmodRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get filesChmodRead;

  /// No description provided for @filesChmodWrite.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get filesChmodWrite;

  /// No description provided for @filesChmodExecute.
  ///
  /// In en, this message translates to:
  /// **'Execute'**
  String get filesChmodExecute;

  /// No description provided for @filesChmodOctalLabel.
  ///
  /// In en, this message translates to:
  /// **'Octal'**
  String get filesChmodOctalLabel;

  /// No description provided for @filesChmodOctalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 1-4 octal digits, 0-7 each'**
  String get filesChmodOctalInvalid;

  /// No description provided for @filesChmodApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get filesChmodApply;

  /// No description provided for @filesShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get filesShowHidden;

  /// No description provided for @filesHideHidden.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden files'**
  String get filesHideHidden;

  /// No description provided for @filesSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get filesSortBy;

  /// No description provided for @filesSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get filesSortName;

  /// No description provided for @filesSortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get filesSortSize;

  /// No description provided for @filesSortModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get filesSortModified;

  /// No description provided for @filesSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get filesSelect;

  /// No description provided for @filesSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get filesSelectAll;

  /// No description provided for @filesSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String filesSelectionCount(int count);

  /// No description provided for @filesDownloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download selected'**
  String get filesDownloadSelected;

  /// No description provided for @filesUploadSelected.
  ///
  /// In en, this message translates to:
  /// **'Upload selected'**
  String get filesUploadSelected;

  /// No description provided for @filesDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get filesDeleteSelected;

  /// No description provided for @filesDeleteSelectedBody.
  ///
  /// In en, this message translates to:
  /// **'{count} items are deleted permanently. This cannot be undone.'**
  String filesDeleteSelectedBody(int count);

  /// No description provided for @importPickKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a key file'**
  String get importPickKeyFile;

  /// No description provided for @importKeyAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {label}'**
  String importKeyAdded(String label);

  /// No description provided for @importNotAKey.
  ///
  /// In en, this message translates to:
  /// **'That file is not a private key.'**
  String get importNotAKey;

  /// No description provided for @importNoteBodyMobile.
  ///
  /// In en, this message translates to:
  /// **'Add a private key from a file on this device.'**
  String get importNoteBodyMobile;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to another device'**
  String get transferTitle;

  /// No description provided for @transferBody.
  ///
  /// In en, this message translates to:
  /// **'Send your servers, keys and tunnels straight to another device on the same network. Nothing goes through a server, and nothing is stored anywhere but the two devices.'**
  String get transferBody;

  /// No description provided for @transferSend.
  ///
  /// In en, this message translates to:
  /// **'Send to a device'**
  String get transferSend;

  /// No description provided for @transferReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive from a device'**
  String get transferReceive;

  /// No description provided for @transferSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan this on the other device'**
  String get transferSendTitle;

  /// No description provided for @transferSendBody.
  ///
  /// In en, this message translates to:
  /// **'Open SSHetu on the other device, choose Receive, and point it at this code.'**
  String get transferSendBody;

  /// No description provided for @transferIncludeSecrets.
  ///
  /// In en, this message translates to:
  /// **'Include keys and passwords'**
  String get transferIncludeSecrets;

  /// No description provided for @transferIncludeSecretsBody.
  ///
  /// In en, this message translates to:
  /// **'Sends the private keys and saved passwords themselves, not just the list of servers.'**
  String get transferIncludeSecretsBody;

  /// No description provided for @transferWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device…'**
  String get transferWaiting;

  /// No description provided for @transferSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {device}'**
  String transferSentTo(String device);

  /// No description provided for @transferReceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the other device\'s code'**
  String get transferReceiveTitle;

  /// No description provided for @transferReceiveBody.
  ///
  /// In en, this message translates to:
  /// **'On the device that has your servers, choose Move to another device, then Send.'**
  String get transferReceiveBody;

  /// No description provided for @transferPasteInstead.
  ///
  /// In en, this message translates to:
  /// **'Paste a code instead'**
  String get transferPasteInstead;

  /// No description provided for @transferPasteHint.
  ///
  /// In en, this message translates to:
  /// **'sshetu://transfer/…'**
  String get transferPasteHint;

  /// No description provided for @transferOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept this transfer?'**
  String get transferOfferTitle;

  /// No description provided for @transferOfferFrom.
  ///
  /// In en, this message translates to:
  /// **'From {device}'**
  String transferOfferFrom(String device);

  /// No description provided for @transferOfferHosts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No servers} =1{1 server} other{{count} servers}}'**
  String transferOfferHosts(int count);

  /// No description provided for @transferOfferKeys.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No keys} =1{1 key} other{{count} keys}}'**
  String transferOfferKeys(int count);

  /// No description provided for @transferOfferTunnels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tunnels} =1{1 tunnel} other{{count} tunnels}}'**
  String transferOfferTunnels(int count);

  /// No description provided for @transferOfferTrusted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No trusted host keys} =1{1 trusted host key} other{{count} trusted host keys}}'**
  String transferOfferTrusted(int count);

  /// No description provided for @transferOfferSecrets.
  ///
  /// In en, this message translates to:
  /// **'Includes private keys and saved passwords'**
  String get transferOfferSecrets;

  /// No description provided for @transferOfferNoSecrets.
  ///
  /// In en, this message translates to:
  /// **'No keys or passwords included'**
  String get transferOfferNoSecrets;

  /// No description provided for @transferOfferReplaces.
  ///
  /// In en, this message translates to:
  /// **'Anything already on this device with the same name is replaced.'**
  String get transferOfferReplaces;

  /// No description provided for @transferAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get transferAccept;

  /// No description provided for @transferReceived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 server received} other{{count} servers received}}'**
  String transferReceived(int count);

  /// No description provided for @transferScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get transferScanAgain;

  /// No description provided for @transferCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'SSHetu needs the camera to scan a code. You can paste the code as text instead.'**
  String get transferCameraDenied;

  /// No description provided for @transferCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get transferCopyCode;

  /// No description provided for @transferCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied. Paste it on the other device.'**
  String get transferCodeCopied;

  /// No description provided for @transferScanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan a code'**
  String get transferScanCode;

  /// No description provided for @menuFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// No description provided for @menuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// No description provided for @menuSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get menuSession;

  /// No description provided for @menuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// No description provided for @menuNewHost.
  ///
  /// In en, this message translates to:
  /// **'New Server…'**
  String get menuNewHost;

  /// No description provided for @menuImport.
  ///
  /// In en, this message translates to:
  /// **'Import from OpenSSH…'**
  String get menuImport;

  /// No description provided for @menuGenerateKey.
  ///
  /// In en, this message translates to:
  /// **'Generate Key…'**
  String get menuGenerateKey;

  /// No description provided for @menuSendToDevice.
  ///
  /// In en, this message translates to:
  /// **'Send to a Device…'**
  String get menuSendToDevice;

  /// No description provided for @menuReceiveFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Receive from a Device…'**
  String get menuReceiveFromDevice;

  /// No description provided for @menuCloseSession.
  ///
  /// In en, this message translates to:
  /// **'Close Session'**
  String get menuCloseSession;

  /// No description provided for @menuNextSession.
  ///
  /// In en, this message translates to:
  /// **'Next Session'**
  String get menuNextSession;

  /// No description provided for @menuPreviousSession.
  ///
  /// In en, this message translates to:
  /// **'Previous Session'**
  String get menuPreviousSession;

  /// No description provided for @menuHosts.
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get menuHosts;

  /// No description provided for @menuKeys.
  ///
  /// In en, this message translates to:
  /// **'Keys'**
  String get menuKeys;

  /// No description provided for @menuTunnels.
  ///
  /// In en, this message translates to:
  /// **'Tunnels'**
  String get menuTunnels;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuTrustedHostKeys.
  ///
  /// In en, this message translates to:
  /// **'Trusted Host Keys'**
  String get menuTrustedHostKeys;

  /// No description provided for @menuDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get menuDiagnostics;

  /// No description provided for @transferFirewallNote.
  ///
  /// In en, this message translates to:
  /// **'macOS may ask whether SSHetu can accept incoming connections. Allow it — the other device connects to this one, so without it nothing can reach you.'**
  String get transferFirewallNote;

  /// No description provided for @transferStepPermission.
  ///
  /// In en, this message translates to:
  /// **'Asking macOS for permission to accept connections…'**
  String get transferStepPermission;

  /// No description provided for @transferStepBinding.
  ///
  /// In en, this message translates to:
  /// **'Opening a port…'**
  String get transferStepBinding;

  /// No description provided for @transferCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transferCancel;

  /// No description provided for @transferNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Sharing hasn\'t started.'**
  String get transferNotStarted;

  /// No description provided for @menuCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get menuCloseTab;

  /// No description provided for @menuWindow.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get menuWindow;

  /// No description provided for @menuMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get menuMinimize;

  /// No description provided for @menuZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get menuZoom;

  /// No description provided for @menuFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Enter Full Screen'**
  String get menuFullScreen;

  /// No description provided for @menuBringAllToFront.
  ///
  /// In en, this message translates to:
  /// **'Bring All to Front'**
  String get menuBringAllToFront;

  /// No description provided for @menuHide.
  ///
  /// In en, this message translates to:
  /// **'Hide SSHetu'**
  String get menuHide;

  /// No description provided for @menuHideOthers.
  ///
  /// In en, this message translates to:
  /// **'Hide Others'**
  String get menuHideOthers;

  /// No description provided for @menuShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get menuShowAll;

  /// No description provided for @menuServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get menuServices;

  /// No description provided for @menuQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit SSHetu'**
  String get menuQuit;

  /// No description provided for @menuAboutApp.
  ///
  /// In en, this message translates to:
  /// **'About SSHetu'**
  String get menuAboutApp;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @backupBody.
  ///
  /// In en, this message translates to:
  /// **'An encrypted copy of your servers, keys and tunnels, saved as a file you keep.'**
  String get backupBody;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Save a backup…'**
  String get backupExport;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup…'**
  String get backupImport;

  /// No description provided for @backupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get backupPassphrase;

  /// No description provided for @backupPassphraseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Repeat passphrase'**
  String get backupPassphraseConfirm;

  /// No description provided for @backupPassphraseHelp.
  ///
  /// In en, this message translates to:
  /// **'This passphrase is the only thing protecting the file. It cannot be recovered — if you lose it, the backup is gone.'**
  String get backupPassphraseHelp;

  /// No description provided for @backupPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passphrases are different.'**
  String get backupPassphraseMismatch;

  /// No description provided for @backupPassphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters.'**
  String backupPassphraseTooShort(int count);

  /// No description provided for @backupStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak — easy to guess'**
  String get backupStrengthWeak;

  /// No description provided for @backupStrengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get backupStrengthFair;

  /// No description provided for @backupStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get backupStrengthStrong;

  /// No description provided for @backupIncludeSecrets.
  ///
  /// In en, this message translates to:
  /// **'Include keys and passwords'**
  String get backupIncludeSecrets;

  /// No description provided for @backupIncludeSecretsBody.
  ///
  /// In en, this message translates to:
  /// **'Without these the backup restores your servers but you will have to supply keys again.'**
  String get backupIncludeSecretsBody;

  /// No description provided for @backupWorking.
  ///
  /// In en, this message translates to:
  /// **'Encrypting…'**
  String get backupWorking;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to {path}'**
  String backupSaved(String path);

  /// No description provided for @backupShared.
  ///
  /// In en, this message translates to:
  /// **'Backup ready to save.'**
  String get backupShared;

  /// No description provided for @backupSaveAnother.
  ///
  /// In en, this message translates to:
  /// **'Save another'**
  String get backupSaveAnother;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore a backup'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup file, then enter the passphrase it was saved with.'**
  String get backupRestoreBody;

  /// No description provided for @backupChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file…'**
  String get backupChooseFile;

  /// No description provided for @backupOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening…'**
  String get backupOpening;

  /// No description provided for @backupOpen.
  ///
  /// In en, this message translates to:
  /// **'Open backup'**
  String get backupOpen;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestore;

  /// No description provided for @backupRestoreWarning.
  ///
  /// In en, this message translates to:
  /// **'Restoring replaces anything on this device with the same name. It cannot be undone.'**
  String get backupRestoreWarning;

  /// No description provided for @backupContents.
  ///
  /// In en, this message translates to:
  /// **'{hosts} servers, {identities} keys, {tunnels} tunnels, {knownHosts} trusted host keys'**
  String backupContents(int hosts, int identities, int tunnels, int knownHosts);

  /// No description provided for @backupWithSecrets.
  ///
  /// In en, this message translates to:
  /// **'Includes private keys and saved passwords.'**
  String get backupWithSecrets;

  /// No description provided for @backupWithoutSecrets.
  ///
  /// In en, this message translates to:
  /// **'Does not include private keys or passwords.'**
  String get backupWithoutSecrets;

  /// No description provided for @backupWrittenOn.
  ///
  /// In en, this message translates to:
  /// **'Saved {date} by SSHetu {version}'**
  String backupWrittenOn(String date, String version);

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored.'**
  String get backupRestored;

  /// No description provided for @menuSaveBackup.
  ///
  /// In en, this message translates to:
  /// **'Save a Backup…'**
  String get menuSaveBackup;

  /// No description provided for @menuRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from a Backup…'**
  String get menuRestoreBackup;

  /// No description provided for @keySetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Use a key instead of a password'**
  String get keySetupTitle;

  /// No description provided for @keySetupBody.
  ///
  /// In en, this message translates to:
  /// **'Adds a public key to this server\'s authorized_keys, checks it really logs you in, and then stops saving your password here.'**
  String get keySetupBody;

  /// No description provided for @keySetupChooseKey.
  ///
  /// In en, this message translates to:
  /// **'Which key?'**
  String get keySetupChooseKey;

  /// No description provided for @keySetupGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate a new key'**
  String get keySetupGenerate;

  /// No description provided for @keySetupStart.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get keySetupStart;

  /// No description provided for @keySetupInstalling.
  ///
  /// In en, this message translates to:
  /// **'Adding the key to the server…'**
  String get keySetupInstalling;

  /// No description provided for @keySetupVerifying.
  ///
  /// In en, this message translates to:
  /// **'Logging in with the key…'**
  String get keySetupVerifying;

  /// No description provided for @keySetupFinishing.
  ///
  /// In en, this message translates to:
  /// **'Tidying up…'**
  String get keySetupFinishing;

  /// No description provided for @keySetupRollingBack.
  ///
  /// In en, this message translates to:
  /// **'Putting the server back…'**
  String get keySetupRollingBack;

  /// No description provided for @keySetupDone.
  ///
  /// In en, this message translates to:
  /// **'Done — {host} now uses {key}, and the saved password has been removed.'**
  String keySetupDone(String host, String key);

  /// No description provided for @keySetupAlreadyPresent.
  ///
  /// In en, this message translates to:
  /// **'That key was already on the server.'**
  String get keySetupAlreadyPresent;

  /// No description provided for @keySetupServerNote.
  ///
  /// In en, this message translates to:
  /// **'This does not change the server\'s own settings. It still accepts passwords from other clients — only this app stops using one.'**
  String get keySetupServerNote;

  /// No description provided for @keySetupNoKeys.
  ///
  /// In en, this message translates to:
  /// **'You have no keys yet. Generate one to continue.'**
  String get keySetupNoKeys;

  /// No description provided for @menuUseKeyInstead.
  ///
  /// In en, this message translates to:
  /// **'Use a Key Instead of a Password…'**
  String get menuUseKeyInstead;

  /// No description provided for @keySetupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Connect to this server first — the key is installed over the session you already have.'**
  String get keySetupUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
