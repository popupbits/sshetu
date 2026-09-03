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
  /// **'SSH Navigator'**
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
  /// **'Share SSH Navigator'**
  String get aboutShare;

  /// No description provided for @aboutShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell someone who\'d find it useful'**
  String get aboutShareSubtitle;

  /// No description provided for @aboutShareMessage.
  ///
  /// In en, this message translates to:
  /// **'I\'ve been using SSH Navigator — you might like it too.'**
  String get aboutShareMessage;

  /// No description provided for @aboutRate.
  ///
  /// In en, this message translates to:
  /// **'Rate SSH Navigator'**
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
  /// **'SSH Navigator support'**
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

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUp;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get authName;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authHaveAccount;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @authSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of SSH Navigator?'**
  String get authSignOutConfirm;

  /// No description provided for @authAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get authAccount;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like an email address'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Passwords must be at least 8 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get authNameRequired;

  /// No description provided for @authRecoverySent.
  ///
  /// In en, this message translates to:
  /// **'Check your email for a reset link'**
  String get authRecoverySent;

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
  /// **'SSH Navigator diagnostics'**
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
  /// **'This device has no ~/.ssh to read. Import a key file instead.'**
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
  /// **'Port forwarding is not wired up yet.'**
  String get tunnelsEmptyBody;

  /// No description provided for @settingsSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsSync;

  /// No description provided for @settingsSyncSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync'**
  String get settingsSyncSignIn;

  /// No description provided for @settingsSyncBody.
  ///
  /// In en, this message translates to:
  /// **'Optional. Everything works on this device without an account.'**
  String get settingsSyncBody;

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
