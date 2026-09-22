import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ne.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ne'),
  ];

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

  /// No description provided for @settingsTerminalTextSize.
  ///
  /// In en, this message translates to:
  /// **'Terminal text size'**
  String get settingsTerminalTextSize;

  /// No description provided for @terminalTextSizePoints.
  ///
  /// In en, this message translates to:
  /// **'{size} pt'**
  String terminalTextSizePoints(int size);

  /// No description provided for @terminalTextSizeSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get terminalTextSizeSmaller;

  /// No description provided for @terminalTextSizeLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get terminalTextSizeLarger;

  /// No description provided for @menuZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get menuZoomIn;

  /// No description provided for @menuZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get menuZoomOut;

  /// No description provided for @menuActualSize.
  ///
  /// In en, this message translates to:
  /// **'Actual Size'**
  String get menuActualSize;

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

  /// No description provided for @terminalMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get terminalMoreActions;

  /// No description provided for @sessionLogStartEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Start logging…'**
  String get sessionLogStartEllipsis;

  /// No description provided for @sessionLogStop.
  ///
  /// In en, this message translates to:
  /// **'Stop logging'**
  String get sessionLogStop;

  /// No description provided for @sessionLogKeyword.
  ///
  /// In en, this message translates to:
  /// **'log record save output'**
  String get sessionLogKeyword;

  /// No description provided for @sessionLogStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Log {session}'**
  String sessionLogStartTitle(String session);

  /// No description provided for @sessionLogStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start logging'**
  String get sessionLogStartAction;

  /// No description provided for @sessionLogFormat.
  ///
  /// In en, this message translates to:
  /// **'Log format'**
  String get sessionLogFormat;

  /// No description provided for @sessionLogFormatPlain.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get sessionLogFormatPlain;

  /// No description provided for @sessionLogFormatPlainHint.
  ///
  /// In en, this message translates to:
  /// **'Readable text, without colours or control codes'**
  String get sessionLogFormatPlainHint;

  /// No description provided for @sessionLogFormatRaw.
  ///
  /// In en, this message translates to:
  /// **'Raw (with colours)'**
  String get sessionLogFormatRaw;

  /// No description provided for @sessionLogFormatRawHint.
  ///
  /// In en, this message translates to:
  /// **'Exactly as received; replay it with cat'**
  String get sessionLogFormatRawHint;

  /// No description provided for @sessionLogFormatAsciicast.
  ///
  /// In en, this message translates to:
  /// **'asciicast (.cast)'**
  String get sessionLogFormatAsciicast;

  /// No description provided for @sessionLogFormatAsciicastHint.
  ///
  /// In en, this message translates to:
  /// **'A timed recording; play it with asciinema'**
  String get sessionLogFormatAsciicastHint;

  /// No description provided for @sessionLogPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Everything the server prints is written to the file. What you type is not logged separately — the server echoes it back, so it appears only as shown on screen. Passwords typed at a prompt are not echoed, so they are not logged.'**
  String get sessionLogPrivacyNote;

  /// No description provided for @sessionLogStarted.
  ///
  /// In en, this message translates to:
  /// **'Logging to {file}'**
  String sessionLogStarted(String file);

  /// No description provided for @sessionLogSaved.
  ///
  /// In en, this message translates to:
  /// **'Log saved: {file}'**
  String sessionLogSaved(String file);

  /// No description provided for @sessionLogShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get sessionLogShare;

  /// No description provided for @sessionLogFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not write the session log'**
  String get sessionLogFailed;

  /// No description provided for @sessionLogIndicator.
  ///
  /// In en, this message translates to:
  /// **'Logging to {file}'**
  String sessionLogIndicator(String file);

  /// No description provided for @sessionLogLarge.
  ///
  /// In en, this message translates to:
  /// **'{file} is over 100 MB and still growing'**
  String sessionLogLarge(String file);

  /// No description provided for @sessionLogMarkerDisconnected.
  ///
  /// In en, this message translates to:
  /// **'connection lost'**
  String get sessionLogMarkerDisconnected;

  /// No description provided for @sessionLogMarkerReconnected.
  ///
  /// In en, this message translates to:
  /// **'reconnected'**
  String get sessionLogMarkerReconnected;

  /// No description provided for @sessionLogMarkerStopped.
  ///
  /// In en, this message translates to:
  /// **'logging stopped'**
  String get sessionLogMarkerStopped;

  /// No description provided for @sessionLogMarkerTabClosed.
  ///
  /// In en, this message translates to:
  /// **'tab closed'**
  String get sessionLogMarkerTabClosed;

  /// No description provided for @sessionLogFolder.
  ///
  /// In en, this message translates to:
  /// **'Session log folder'**
  String get sessionLogFolder;

  /// No description provided for @sessionLogFolderNone.
  ///
  /// In en, this message translates to:
  /// **'Not chosen — you are asked where to save each log'**
  String get sessionLogFolderNone;

  /// No description provided for @sessionLogFolderClear.
  ///
  /// In en, this message translates to:
  /// **'Clear folder'**
  String get sessionLogFolderClear;

  /// No description provided for @sessionLogAlways.
  ///
  /// In en, this message translates to:
  /// **'Always log new sessions'**
  String get sessionLogAlways;

  /// No description provided for @sessionLogAlwaysBody.
  ///
  /// In en, this message translates to:
  /// **'Every new terminal tab writes its output to a log file without asking.'**
  String get sessionLogAlwaysBody;

  /// No description provided for @sessionLogAlwaysNeedsFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a log folder first, so logs have somewhere to go without asking.'**
  String get sessionLogAlwaysNeedsFolder;

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

  /// No description provided for @terminalNothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected. Long-press the terminal to select text, then copy.'**
  String get terminalNothingSelected;

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
  /// **'A new keypair, made on this device. The private half stays in this device\'s secure storage and never leaves it.'**
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

  /// No description provided for @keysTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Key type'**
  String get keysTypeLabel;

  /// No description provided for @keysTypeEd25519.
  ///
  /// In en, this message translates to:
  /// **'Ed25519 (recommended)'**
  String get keysTypeEd25519;

  /// No description provided for @keysTypeEcdsaP256.
  ///
  /// In en, this message translates to:
  /// **'ECDSA P-256'**
  String get keysTypeEcdsaP256;

  /// No description provided for @keysTypeEcdsaP384.
  ///
  /// In en, this message translates to:
  /// **'ECDSA P-384'**
  String get keysTypeEcdsaP384;

  /// No description provided for @keysTypeRsa3072.
  ///
  /// In en, this message translates to:
  /// **'RSA 3072'**
  String get keysTypeRsa3072;

  /// No description provided for @keysTypeRsa4096.
  ///
  /// In en, this message translates to:
  /// **'RSA 4096'**
  String get keysTypeRsa4096;

  /// No description provided for @keysTypeHelp.
  ///
  /// In en, this message translates to:
  /// **'Ed25519 works with every current server. Choose another only if a server or policy requires it.'**
  String get keysTypeHelp;

  /// No description provided for @keysPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase (optional)'**
  String get keysPassphraseLabel;

  /// No description provided for @keysPassphraseHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to rely on this device\'s lock. If set, you will be asked for it when connecting, and it cannot be recovered.'**
  String get keysPassphraseHelp;

  /// No description provided for @keysPassphraseRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat passphrase'**
  String get keysPassphraseRepeat;

  /// No description provided for @keysPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passphrases don\'t match.'**
  String get keysPassphraseMismatch;

  /// No description provided for @keysGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get keysGenerating;

  /// No description provided for @keysGeneratingSlow.
  ///
  /// In en, this message translates to:
  /// **'Generating an RSA key. This can take a few seconds.'**
  String get keysGeneratingSlow;

  /// No description provided for @keysGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'The key could not be generated.'**
  String get keysGenerateFailed;

  /// No description provided for @keysShare.
  ///
  /// In en, this message translates to:
  /// **'Share public key'**
  String get keysShare;

  /// No description provided for @keysPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste key'**
  String get keysPaste;

  /// No description provided for @paletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get paletteTitle;

  /// No description provided for @paletteSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search servers, tabs, snippets and actions'**
  String get paletteSearchHint;

  /// No description provided for @paletteOpenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search everything'**
  String get paletteOpenTooltip;

  /// No description provided for @menuCommandPalette.
  ///
  /// In en, this message translates to:
  /// **'Command Palette…'**
  String get menuCommandPalette;

  /// Shown in the command palette when the typed query matches no item
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”'**
  String paletteNoResults(String query);

  /// No description provided for @paletteNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try fewer letters, or part of a hostname.'**
  String get paletteNoResultsBody;

  /// No description provided for @paletteEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to search yet'**
  String get paletteEmptyTitle;

  /// No description provided for @paletteEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a server and it shows up here, with its tabs, tunnels and snippets.'**
  String get paletteEmptyBody;

  /// No description provided for @paletteRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get paletteRecent;

  /// No description provided for @paletteKeyHint.
  ///
  /// In en, this message translates to:
  /// **'↑↓ to move · Enter to run · Tab for other actions · Esc to close'**
  String get paletteKeyHint;

  /// No description provided for @paletteCategoryHost.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get paletteCategoryHost;

  /// No description provided for @paletteCategorySession.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get paletteCategorySession;

  /// No description provided for @paletteCategorySnippet.
  ///
  /// In en, this message translates to:
  /// **'Snippet'**
  String get paletteCategorySnippet;

  /// No description provided for @paletteCategoryTunnel.
  ///
  /// In en, this message translates to:
  /// **'Tunnel'**
  String get paletteCategoryTunnel;

  /// No description provided for @paletteCategorySetting.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get paletteCategorySetting;

  /// No description provided for @paletteCategoryAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get paletteCategoryAction;

  /// No description provided for @paletteSwitchTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to'**
  String get paletteSwitchTo;

  /// No description provided for @paletteOpenFiles.
  ///
  /// In en, this message translates to:
  /// **'Open files'**
  String get paletteOpenFiles;

  /// No description provided for @paletteTunnelStart.
  ///
  /// In en, this message translates to:
  /// **'Start tunnel'**
  String get paletteTunnelStart;

  /// No description provided for @paletteTunnelStop.
  ///
  /// In en, this message translates to:
  /// **'Stop tunnel'**
  String get paletteTunnelStop;

  /// No description provided for @paletteToggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Switch between light and dark theme'**
  String get paletteToggleTheme;

  /// A command palette item that navigates to one of the app's main sections
  ///
  /// In en, this message translates to:
  /// **'Go to {destination}'**
  String paletteGoTo(String destination);

  /// A command palette item that opens Settings scrolled to one section
  ///
  /// In en, this message translates to:
  /// **'Settings › {section}'**
  String paletteSettingsSection(String section);

  /// No description provided for @keysPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a private key'**
  String get keysPasteTitle;

  /// No description provided for @keysPasteBody.
  ///
  /// In en, this message translates to:
  /// **'An OpenSSH or PEM private key. It is stored in this device\'s secure storage and never logged.'**
  String get keysPasteBody;

  /// No description provided for @keysPasteField.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get keysPasteField;

  /// No description provided for @keysPasteCheck.
  ///
  /// In en, this message translates to:
  /// **'Check key'**
  String get keysPasteCheck;

  /// No description provided for @keysPasteSave.
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get keysPasteSave;

  /// No description provided for @keysPastePassphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get keysPastePassphrase;

  /// No description provided for @keysPastePassphraseHelp.
  ///
  /// In en, this message translates to:
  /// **'Used only to read the key now. It is not saved: you will be asked for it when connecting.'**
  String get keysPastePassphraseHelp;

  /// No description provided for @keysPasteEmpty.
  ///
  /// In en, this message translates to:
  /// **'Paste a private key first.'**
  String get keysPasteEmpty;

  /// No description provided for @keysPastePublicKey.
  ///
  /// In en, this message translates to:
  /// **'That is a public key. Paste the private key instead: the file without .pub, starting with -----BEGIN.'**
  String get keysPastePublicKey;

  /// No description provided for @keysPasteNotAKey.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a private key.'**
  String get keysPasteNotAKey;

  /// No description provided for @keysPasteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This key format can\'t be used. OpenSSH, PEM RSA and PEM EC keys are supported; convert others with ssh-keygen or PuTTYgen.'**
  String get keysPasteUnsupported;

  /// No description provided for @keysPasteNeedsPassphrase.
  ///
  /// In en, this message translates to:
  /// **'This key is protected. Enter its passphrase to read it.'**
  String get keysPasteNeedsPassphrase;

  /// No description provided for @keysPasteWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'That passphrase doesn\'t open this key.'**
  String get keysPasteWrongPassphrase;

  /// No description provided for @keysPasteDamaged.
  ///
  /// In en, this message translates to:
  /// **'This key is damaged or incomplete. Copy it again, including the BEGIN and END lines.'**
  String get keysPasteDamaged;

  /// No description provided for @keysPasteDuplicate.
  ///
  /// In en, this message translates to:
  /// **'You already have this key, as {label}.'**
  String keysPasteDuplicate(String label);

  /// No description provided for @keysPasteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The key could not be saved to this device\'s secure storage.'**
  String get keysPasteSaveFailed;

  /// No description provided for @keysPublicKeyHeading.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get keysPublicKeyHeading;

  /// No description provided for @keysFingerprintHeading.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get keysFingerprintHeading;

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

  /// No description provided for @reachabilityUp.
  ///
  /// In en, this message translates to:
  /// **'Reachable · {ms} ms'**
  String reachabilityUp(int ms);

  /// No description provided for @reachabilityDown.
  ///
  /// In en, this message translates to:
  /// **'Unreachable ({reason})'**
  String reachabilityDown(String reason);

  /// No description provided for @reachabilityTimedOut.
  ///
  /// In en, this message translates to:
  /// **'timed out'**
  String get reachabilityTimedOut;

  /// No description provided for @reachabilityRefused.
  ///
  /// In en, this message translates to:
  /// **'connection refused'**
  String get reachabilityRefused;

  /// No description provided for @reachabilityUnresolved.
  ///
  /// In en, this message translates to:
  /// **'address not found'**
  String get reachabilityUnresolved;

  /// No description provided for @reachabilityNoRoute.
  ///
  /// In en, this message translates to:
  /// **'no route to host'**
  String get reachabilityNoRoute;

  /// No description provided for @reachabilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get reachabilityUnknown;

  /// No description provided for @reachabilitySession.
  ///
  /// In en, this message translates to:
  /// **'Connected · a session is open'**
  String get reachabilitySession;

  /// No description provided for @reachabilityCheckedNow.
  ///
  /// In en, this message translates to:
  /// **'Checked just now'**
  String get reachabilityCheckedNow;

  /// No description provided for @reachabilityCheckedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Checked 1 min ago} other{Checked {count} min ago}}'**
  String reachabilityCheckedMinutes(int count);

  /// No description provided for @reachabilityCheckedHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Checked 1 hour ago} other{Checked {count} hours ago}}'**
  String reachabilityCheckedHours(int count);

  /// No description provided for @settingsReachability.
  ///
  /// In en, this message translates to:
  /// **'Check whether hosts are reachable'**
  String get settingsReachability;

  /// No description provided for @settingsReachabilityBody.
  ///
  /// In en, this message translates to:
  /// **'While the host list is on screen, briefly opens a connection to each server\'s port — never signs in. Slower checks are kinder to servers with connection limits.'**
  String get settingsReachabilityBody;

  /// No description provided for @settingsReachabilityOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsReachabilityOff;

  /// No description provided for @settingsReachability30s.
  ///
  /// In en, this message translates to:
  /// **'30 s'**
  String get settingsReachability30s;

  /// No description provided for @settingsReachability1m.
  ///
  /// In en, this message translates to:
  /// **'1 min'**
  String get settingsReachability1m;

  /// No description provided for @settingsReachability5m.
  ///
  /// In en, this message translates to:
  /// **'5 min'**
  String get settingsReachability5m;

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

  /// Title of the dialog showing questions the SSH server asks during keyboard-interactive sign-in (a password, a one-time code), used when the server gives no title of its own
  ///
  /// In en, this message translates to:
  /// **'Server sign-in'**
  String get interactiveAuthTitle;

  /// Button that sends the answers typed into the server sign-in dialog
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get interactiveAuthSubmit;

  /// Label for an answer field when the server's question has no text
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get interactiveAuthAnswerLabel;

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

  /// No description provided for @knownHostsImport.
  ///
  /// In en, this message translates to:
  /// **'Import from known_hosts'**
  String get knownHostsImport;

  /// No description provided for @knownHostsImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import trusted host keys'**
  String get knownHostsImportTitle;

  /// No description provided for @knownHostsImportFrom.
  ///
  /// In en, this message translates to:
  /// **'From {path}'**
  String knownHostsImportFrom(String path);

  /// No description provided for @knownHostsImportNew.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new key to trust} other{{count} new keys to trust}}'**
  String knownHostsImportNew(int count);

  /// No description provided for @knownHostsImportNewHashed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 of them has a hashed name. It is stored as it is and recognised when you connect to that host, but it cannot be listed by name.} other{{count} of them have hashed names. They are stored as they are and recognised when you connect to those hosts, but cannot be listed by name.}}'**
  String knownHostsImportNewHashed(int count);

  /// No description provided for @knownHostsImportNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing new to import'**
  String get knownHostsImportNothing;

  /// No description provided for @knownHostsImportAlready.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 already trusted} other{{count} already trusted}}'**
  String knownHostsImportAlready(int count);

  /// No description provided for @knownHostsImportConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 host conflicts with a key you already trust} other{{count} hosts conflict with keys you already trust}}'**
  String knownHostsImportConflicts(int count);

  /// No description provided for @knownHostsImportConflictsBody.
  ///
  /// In en, this message translates to:
  /// **'These are left unchanged. If a server really was rebuilt, forget its old key here first, then import again.'**
  String get knownHostsImportConflictsBody;

  /// No description provided for @knownHostsImportTrusted.
  ///
  /// In en, this message translates to:
  /// **'Trusted: {key}'**
  String knownHostsImportTrusted(String key);

  /// No description provided for @knownHostsImportInFile.
  ///
  /// In en, this message translates to:
  /// **'In the file: {key}'**
  String knownHostsImportInFile(String key);

  /// No description provided for @knownHostsImportSkipped.
  ///
  /// In en, this message translates to:
  /// **'Not imported'**
  String get knownHostsImportSkipped;

  /// No description provided for @knownHostsImportRevoked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 @revoked line — this app pins keys it trusts and keeps no list of keys to refuse} other{{count} @revoked lines — this app pins keys it trusts and keeps no list of keys to refuse}}'**
  String knownHostsImportRevoked(int count);

  /// No description provided for @knownHostsImportCertAuthority.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 @cert-authority line — host certificates are not supported} other{{count} @cert-authority lines — host certificates are not supported}}'**
  String knownHostsImportCertAuthority(int count);

  /// No description provided for @knownHostsImportWildcards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 wildcard or negated name — a trusted key is for one exact host} other{{count} wildcard or negated names — a trusted key is for one exact host}}'**
  String knownHostsImportWildcards(int count);

  /// No description provided for @knownHostsImportUnsupported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 key of a type this app cannot verify} other{{count} keys of a type this app cannot verify}}'**
  String knownHostsImportUnsupported(int count);

  /// No description provided for @knownHostsImportMalformed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unreadable line ({lines})} other{{count} unreadable lines ({lines})}}'**
  String knownHostsImportMalformed(int count, String lines);

  /// No description provided for @knownHostsImportAlternates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 extra key for a host — one key is kept per host, the type a connection uses first} other{{count} extra keys for hosts — one key is kept per host, the type a connection uses first}}'**
  String knownHostsImportAlternates(int count);

  /// No description provided for @knownHostsImportAction.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Import} =1{Import 1 key} other{Import {count} keys}}'**
  String knownHostsImportAction(int count);

  /// No description provided for @knownHostsImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Trusted 1 host key} other{Trusted {count} host keys}}'**
  String knownHostsImported(int count);

  /// No description provided for @knownHostsImportReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read that file'**
  String get knownHostsImportReadFailed;

  /// No description provided for @knownHostsImportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is too large to be a known_hosts file'**
  String get knownHostsImportTooLarge;

  /// No description provided for @knownHostsHashedTitle.
  ///
  /// In en, this message translates to:
  /// **'Hashed host name (imported)'**
  String get knownHostsHashedTitle;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsAppLock.
  ///
  /// In en, this message translates to:
  /// **'Require unlock for saved credentials'**
  String get settingsAppLock;

  /// Subtitle of the app-lock switch. The PIN fallback is mentioned on purpose: the lock never relies on biometrics alone.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you with a fingerprint, your face or the device PIN before a saved password or key is used.'**
  String get settingsAppLockBody;

  /// No description provided for @settingsAppLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Set up a screen lock, fingerprint, face or Windows Hello on this device first.'**
  String get settingsAppLockUnavailable;

  /// No description provided for @settingsAppLockCancelled.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed, so the setting was not changed.'**
  String get settingsAppLockCancelled;

  /// No description provided for @settingsAppLockLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Unlock your device, then try again.'**
  String get settingsAppLockLockedOut;

  /// No description provided for @settingsAppLockFailed.
  ///
  /// In en, this message translates to:
  /// **'This device could not confirm it\'s you.'**
  String get settingsAppLockFailed;

  /// Shown by the system's fingerprint, face or PIN prompt when turning the lock on.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you to lock your saved credentials'**
  String get appLockEnableReason;

  /// No description provided for @appLockDisableReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you to stop locking your saved credentials'**
  String get appLockDisableReason;

  /// Shown by the system's fingerprint, face or PIN prompt when a connection needs a saved password or key.
  ///
  /// In en, this message translates to:
  /// **'Unlock your saved SSH credentials'**
  String get appLockUnlockReason;

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

  /// No description provided for @tunnelFarEndListening.
  ///
  /// In en, this message translates to:
  /// **'Target listening'**
  String get tunnelFarEndListening;

  /// No description provided for @tunnelFarEndNotListening.
  ///
  /// In en, this message translates to:
  /// **'Nothing listening on target'**
  String get tunnelFarEndNotListening;

  /// No description provided for @tunnelFarEndHelp.
  ///
  /// In en, this message translates to:
  /// **'Checked from the server every 30 seconds while this screen is open.'**
  String get tunnelFarEndHelp;

  /// No description provided for @portsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ports on this server'**
  String get portsTitle;

  /// No description provided for @portsTab.
  ///
  /// In en, this message translates to:
  /// **'Ports'**
  String get portsTab;

  /// No description provided for @portsLoading.
  ///
  /// In en, this message translates to:
  /// **'Looking for listening ports…'**
  String get portsLoading;

  /// No description provided for @portsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No listening ports found'**
  String get portsEmpty;

  /// No description provided for @portsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start a server on this machine and it shows up here within a few seconds. System services such as SSH and DNS are left out.'**
  String get portsEmptyBody;

  /// No description provided for @portsOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'The list resumes when the session reconnects.'**
  String get portsOfflineBody;

  /// No description provided for @portsError.
  ///
  /// In en, this message translates to:
  /// **'Could not list this server\'s ports: {error}'**
  String portsError(String error);

  /// No description provided for @portsLoopbackOnly.
  ///
  /// In en, this message translates to:
  /// **'This server only'**
  String get portsLoopbackOnly;

  /// No description provided for @portsAllInterfaces.
  ///
  /// In en, this message translates to:
  /// **'All interfaces'**
  String get portsAllInterfaces;

  /// No description provided for @portsForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get portsForward;

  /// No description provided for @portsForwardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Forward a port on this device to port {port} on the server'**
  String portsForwardTooltip(int port);

  /// No description provided for @portsForwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not forward port {port}: {error}'**
  String portsForwardFailed(int port, String error);

  /// No description provided for @portsForwardActions.
  ///
  /// In en, this message translates to:
  /// **'Forward actions'**
  String get portsForwardActions;

  /// No description provided for @portsOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get portsOpenInBrowser;

  /// No description provided for @portsCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get portsCopyAddress;

  /// No description provided for @portsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {address}'**
  String portsCopied(String address);

  /// No description provided for @portsSaveAsTunnel.
  ///
  /// In en, this message translates to:
  /// **'Save as tunnel'**
  String get portsSaveAsTunnel;

  /// No description provided for @portsSavedAsTunnel.
  ///
  /// In en, this message translates to:
  /// **'Saved as tunnel \"{label}\"'**
  String portsSavedAsTunnel(String label);

  /// No description provided for @portsStopForward.
  ///
  /// In en, this message translates to:
  /// **'Stop forward'**
  String get portsStopForward;

  /// No description provided for @settingsStartTunnelsAtLaunch.
  ///
  /// In en, this message translates to:
  /// **'Start auto-start tunnels when SSHetu opens'**
  String get settingsStartTunnelsAtLaunch;

  /// No description provided for @settingsStartTunnelsAtLaunchBody.
  ///
  /// In en, this message translates to:
  /// **'Tunnels set to start automatically connect as soon as the app opens, instead of waiting for a terminal to their server. SSHetu then connects to those servers without asking first.'**
  String get settingsStartTunnelsAtLaunchBody;

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

  /// Row menu action, dialog title and confirm button for renaming a file or folder. F2 does the same on a keyboard.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get filesRename;

  /// Pane header action and dialog title for creating a folder in the pane's current directory.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get filesNewFolder;

  /// No description provided for @filesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get filesCreate;

  /// No description provided for @filesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get filesNameLabel;

  /// No description provided for @filesNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get filesNameEmpty;

  /// No description provided for @filesNameSeparator.
  ///
  /// In en, this message translates to:
  /// **'A name cannot contain a path separator such as /'**
  String get filesNameSeparator;

  /// No description provided for @filesNameReserved.
  ///
  /// In en, this message translates to:
  /// **'“.” and “..” are reserved and cannot be used as names'**
  String get filesNameReserved;

  /// No description provided for @filesNameExists.
  ///
  /// In en, this message translates to:
  /// **'Something called {name} is already here'**
  String filesNameExists(String name);

  /// Shown when a file action fails for a reason the app did not anticipate; the error itself is recorded in the diagnostics log.
  ///
  /// In en, this message translates to:
  /// **'That did not work. Details are in Settings → Diagnostics.'**
  String get filesActionFailed;

  /// No description provided for @filesConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Some files are already there'**
  String get filesConflictTitle;

  /// Asked once per folder transfer when files with the same names exist at the destination.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file in {name} already exists at the destination.} other{{count} files in {name} already exist at the destination.}} The choice applies to all of them.'**
  String filesConflictBody(int count, String name);

  /// No description provided for @filesConflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get filesConflictOverwrite;

  /// No description provided for @filesConflictSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip existing'**
  String get filesConflictSkip;

  /// No description provided for @filesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get filesEdit;

  /// No description provided for @filesDropUpload.
  ///
  /// In en, this message translates to:
  /// **'Drop to upload to {folder}'**
  String filesDropUpload(String folder);

  /// No description provided for @filesDropDownload.
  ///
  /// In en, this message translates to:
  /// **'Drop to download to {folder}'**
  String filesDropDownload(String folder);

  /// No description provided for @filesDragCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String filesDragCount(int count);

  /// No description provided for @editorRevert.
  ///
  /// In en, this message translates to:
  /// **'Revert to saved'**
  String get editorRevert;

  /// Tooltip on the editor's save button; keys is the platform's save chord, e.g. Ctrl+S.
  ///
  /// In en, this message translates to:
  /// **'Save ({keys})'**
  String editorSaveTooltip(String keys);

  /// No description provided for @editorUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get editorUnsaved;

  /// No description provided for @editorSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String editorSaved(String name);

  /// No description provided for @editorReloaded.
  ///
  /// In en, this message translates to:
  /// **'Reloaded {name} from the server'**
  String editorReloaded(String name);

  /// No description provided for @editorUtf8.
  ///
  /// In en, this message translates to:
  /// **'UTF-8'**
  String get editorUtf8;

  /// No description provided for @editorUtf8Bom.
  ///
  /// In en, this message translates to:
  /// **'UTF-8 with BOM'**
  String get editorUtf8Bom;

  /// No description provided for @editorLf.
  ///
  /// In en, this message translates to:
  /// **'LF'**
  String get editorLf;

  /// No description provided for @editorCrlf.
  ///
  /// In en, this message translates to:
  /// **'CRLF'**
  String get editorCrlf;

  /// No description provided for @editorMixedEndings.
  ///
  /// In en, this message translates to:
  /// **'Mixed line endings, kept as they are'**
  String get editorMixedEndings;

  /// No description provided for @editorTooLargeTitle.
  ///
  /// In en, this message translates to:
  /// **'Too large to edit here'**
  String get editorTooLargeTitle;

  /// No description provided for @editorTooLargeBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is larger than {limit}. Download it and open it in an editor on this device instead.'**
  String editorTooLargeBody(String name, String limit);

  /// No description provided for @editorBinaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Not a text file'**
  String get editorBinaryTitle;

  /// No description provided for @editorBinaryBody.
  ///
  /// In en, this message translates to:
  /// **'{name} contains binary data, so it cannot be edited as text.'**
  String editorBinaryBody(String name);

  /// No description provided for @editorNotUtf8Title.
  ///
  /// In en, this message translates to:
  /// **'Not UTF-8 text'**
  String get editorNotUtf8Title;

  /// No description provided for @editorNotUtf8Body.
  ///
  /// In en, this message translates to:
  /// **'{name} is not valid UTF-8. Saving it from here could change characters you never touched, so it is not opened.'**
  String editorNotUtf8Body(String name);

  /// No description provided for @editorNotAFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Not a file'**
  String get editorNotAFileTitle;

  /// No description provided for @editorNotAFileBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is a folder.'**
  String editorNotAFileBody(String name);

  /// No description provided for @editorLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file'**
  String get editorLoadFailedTitle;

  /// No description provided for @editorConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Changed on the server'**
  String get editorConflictTitle;

  /// No description provided for @editorConflictBody.
  ///
  /// In en, this message translates to:
  /// **'{name} was changed on the server after you opened it. Overwrite that change with yours, reload the server\'s version and lose your edits, or cancel and decide later.'**
  String editorConflictBody(String name);

  /// No description provided for @editorConflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get editorConflictOverwrite;

  /// No description provided for @editorConflictReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get editorConflictReload;

  /// No description provided for @editorDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get editorDiscardTitle;

  /// No description provided for @editorDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits to {name} have not been saved.'**
  String editorDiscardBody(String name);

  /// No description provided for @editorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get editorDiscard;

  /// A folder transfer that is still listing its contents and checking the destination.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get filesFolderPreparing;

  /// No description provided for @filesFolderProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} files'**
  String filesFolderProgress(int done, int total);

  /// A folder transfer that was cancelled or failed partway; the files already finished were kept.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} files transferred'**
  String filesFolderTransferred(int done, int total);

  /// Symlinks, which a folder transfer never follows, plus folders past its depth limit.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped (links or too deep)'**
  String filesFolderSkipped(int count);

  /// Files a folder transfer did not copy because they already existed and the user chose Skip existing.
  ///
  /// In en, this message translates to:
  /// **'{count} already there'**
  String filesFolderExistingSkipped(int count);

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

  /// No description provided for @menuSplitRight.
  ///
  /// In en, this message translates to:
  /// **'Split Right'**
  String get menuSplitRight;

  /// No description provided for @menuSplitDown.
  ///
  /// In en, this message translates to:
  /// **'Split Down'**
  String get menuSplitDown;

  /// No description provided for @menuClosePane.
  ///
  /// In en, this message translates to:
  /// **'Close Pane'**
  String get menuClosePane;

  /// No description provided for @menuNextPane.
  ///
  /// In en, this message translates to:
  /// **'Next Pane'**
  String get menuNextPane;

  /// No description provided for @menuPreviousPane.
  ///
  /// In en, this message translates to:
  /// **'Previous Pane'**
  String get menuPreviousPane;

  /// No description provided for @menuMaximizePane.
  ///
  /// In en, this message translates to:
  /// **'Maximize Pane'**
  String get menuMaximizePane;

  /// No description provided for @menuTypeInAllPanes.
  ///
  /// In en, this message translates to:
  /// **'Type in All Panes'**
  String get menuTypeInAllPanes;

  /// No description provided for @menuStopTypingInAllPanes.
  ///
  /// In en, this message translates to:
  /// **'Stop Typing in All Panes'**
  String get menuStopTypingInAllPanes;

  /// No description provided for @paneSplitRight.
  ///
  /// In en, this message translates to:
  /// **'Split right'**
  String get paneSplitRight;

  /// No description provided for @paneSplitDown.
  ///
  /// In en, this message translates to:
  /// **'Split down'**
  String get paneSplitDown;

  /// No description provided for @paneClose.
  ///
  /// In en, this message translates to:
  /// **'Close pane'**
  String get paneClose;

  /// No description provided for @paneMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize pane'**
  String get paneMaximize;

  /// No description provided for @paneRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore pane'**
  String get paneRestore;

  /// No description provided for @paneTypeInAll.
  ///
  /// In en, this message translates to:
  /// **'Type in all panes'**
  String get paneTypeInAll;

  /// No description provided for @paneStopTypingInAll.
  ///
  /// In en, this message translates to:
  /// **'Stop typing in all panes'**
  String get paneStopTypingInAll;

  /// Banner on a pane of a split tab with 'type in all panes' on: what is typed here also goes to this many other connected panes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Typing in all panes · 1 other pane receives this} other{Typing in all panes · {count} other panes receive this}}'**
  String paneBroadcastBanner(int count);

  /// No description provided for @paneBroadcastReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receives what is typed in any pane'**
  String get paneBroadcastReceiving;

  /// No description provided for @paneBroadcastExcluded.
  ///
  /// In en, this message translates to:
  /// **'Left out of typing in all panes'**
  String get paneBroadcastExcluded;

  /// No description provided for @paneBroadcastExclude.
  ///
  /// In en, this message translates to:
  /// **'Leave this pane out'**
  String get paneBroadcastExclude;

  /// No description provided for @paneBroadcastInclude.
  ///
  /// In en, this message translates to:
  /// **'Include this pane'**
  String get paneBroadcastInclude;

  /// No description provided for @paneBroadcastStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get paneBroadcastStop;

  /// No description provided for @paneSwitcherLabel.
  ///
  /// In en, this message translates to:
  /// **'Panes in this tab'**
  String get paneSwitcherLabel;

  /// Badge on a workspace tab that holds a split layout
  ///
  /// In en, this message translates to:
  /// **'{count} panes'**
  String paneCount(int count);

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

  /// No description provided for @menuSnippets.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get menuSnippets;

  /// No description provided for @menuSnippetsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Snippets…'**
  String get menuSnippetsEllipsis;

  /// No description provided for @navSnippets.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get navSnippets;

  /// No description provided for @snippetsAdd.
  ///
  /// In en, this message translates to:
  /// **'New snippet'**
  String get snippetsAdd;

  /// No description provided for @snippetsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search snippets'**
  String get snippetsSearch;

  /// No description provided for @snippetsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No snippets yet'**
  String get snippetsEmptyTitle;

  /// No description provided for @snippetsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Save commands you type often, then insert or run them in any session. Use {example} for a value to fill in each time.'**
  String snippetsEmptyBody(String example);

  /// No description provided for @snippetsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No snippets match'**
  String get snippetsNoMatch;

  /// No description provided for @snippetsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get snippetsEdit;

  /// No description provided for @snippetsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get snippetsDelete;

  /// No description provided for @snippetsMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get snippetsMore;

  /// No description provided for @snippetsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this snippet?'**
  String get snippetsDeleteConfirm;

  /// No description provided for @snippetsNoSession.
  ///
  /// In en, this message translates to:
  /// **'Open a session first — a snippet needs somewhere to go.'**
  String get snippetsNoSession;

  /// No description provided for @snippetCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get snippetCopy;

  /// No description provided for @snippetCopied.
  ///
  /// In en, this message translates to:
  /// **'Command copied'**
  String get snippetCopied;

  /// No description provided for @snippetEditorNew.
  ///
  /// In en, this message translates to:
  /// **'New snippet'**
  String get snippetEditorNew;

  /// No description provided for @snippetEditorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit snippet'**
  String get snippetEditorEdit;

  /// No description provided for @snippetEditorLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get snippetEditorLabel;

  /// No description provided for @snippetEditorLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Restart nginx'**
  String get snippetEditorLabelHint;

  /// No description provided for @snippetEditorBody.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get snippetEditorBody;

  /// No description provided for @snippetEditorBodyHint.
  ///
  /// In en, this message translates to:
  /// **'For example: {example}'**
  String snippetEditorBodyHint(String example);

  /// No description provided for @snippetEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get snippetEditorDescription;

  /// No description provided for @snippetEditorTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get snippetEditorTags;

  /// Explains placeholder syntax; the placeholders are literal examples of that syntax
  ///
  /// In en, this message translates to:
  /// **'{ask} asks for a value when used, {prefilled} prefills it. {builtins} come from the session.'**
  String snippetEditorVariablesHint(
    String ask,
    String prefilled,
    String builtins,
  );

  /// No description provided for @snippetEditorAsks.
  ///
  /// In en, this message translates to:
  /// **'Asks for: {names}'**
  String snippetEditorAsks(String names);

  /// No description provided for @snippetEditorFills.
  ///
  /// In en, this message translates to:
  /// **'Fills in: {names}'**
  String snippetEditorFills(String names);

  /// Heading of the snippet picker, naming the session the snippet will be typed into
  ///
  /// In en, this message translates to:
  /// **'Snippets · {session}'**
  String snippetPickerTitle(String session);

  /// No description provided for @snippetPickerManage.
  ///
  /// In en, this message translates to:
  /// **'Manage snippets'**
  String get snippetPickerManage;

  /// No description provided for @snippetInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get snippetInsert;

  /// No description provided for @snippetRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get snippetRun;

  /// No description provided for @snippetRunOn.
  ///
  /// In en, this message translates to:
  /// **'Run on…'**
  String get snippetRunOn;

  /// No description provided for @snippetRunOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Run on which sessions?'**
  String get snippetRunOnTitle;

  /// No description provided for @snippetRunOnAll.
  ///
  /// In en, this message translates to:
  /// **'All connected sessions'**
  String get snippetRunOnAll;

  /// No description provided for @snippetRunOnNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get snippetRunOnNotConnected;

  /// No description provided for @snippetRunOnConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Run in 1 session} other{Run in {count} sessions}}'**
  String snippetRunOnConfirm(int count);

  /// No description provided for @snippetVariablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in the snippet'**
  String get snippetVariablesTitle;

  /// No description provided for @snippetVariablesPreview.
  ///
  /// In en, this message translates to:
  /// **'Will type'**
  String get snippetVariablesPreview;

  /// No description provided for @snippetNotConnected.
  ///
  /// In en, this message translates to:
  /// **'This session isn\'t connected, so nothing was typed.'**
  String get snippetNotConnected;

  /// No description provided for @snippetEmpty.
  ///
  /// In en, this message translates to:
  /// **'That snippet has nothing to type.'**
  String get snippetEmpty;

  /// No description provided for @snippetMultilineInsertRefused.
  ///
  /// In en, this message translates to:
  /// **'This shell would run each line as it arrived, so the snippet was not inserted. Use Run instead.'**
  String get snippetMultilineInsertRefused;

  /// No description provided for @snippetRanIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ran in 1 session} other{Ran in {count} sessions}}'**
  String snippetRanIn(int count);

  /// No description provided for @snippetRanInSome.
  ///
  /// In en, this message translates to:
  /// **'Ran in {sent} of {total} sessions — the rest weren\'t connected'**
  String snippetRanInSome(int sent, int total);

  /// No description provided for @transferOfferSnippets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No snippets} =1{1 snippet} other{{count} snippets}}'**
  String transferOfferSnippets(int count);

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

  /// No description provided for @transferFirewallNoteWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows may ask whether SSHetu can communicate on this network. Allow it on your private network — the other device connects to this one, so without it nothing can reach you.'**
  String get transferFirewallNoteWindows;

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

  /// No description provided for @secretNotErased.
  ///
  /// In en, this message translates to:
  /// **'Removed from SSHetu, but the system keychain would not erase the stored secret.'**
  String get secretNotErased;

  /// No description provided for @diagnosticsCopyOne.
  ///
  /// In en, this message translates to:
  /// **'Copy this error'**
  String get diagnosticsCopyOne;

  /// No description provided for @diagnosticsRemoveOne.
  ///
  /// In en, this message translates to:
  /// **'Remove this error'**
  String get diagnosticsRemoveOne;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied.'**
  String get diagnosticsCopied;

  /// No description provided for @diagnosticsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed.'**
  String get diagnosticsRemoved;

  /// No description provided for @settingsDefaultKey.
  ///
  /// In en, this message translates to:
  /// **'Default key'**
  String get settingsDefaultKey;

  /// No description provided for @settingsDefaultKeyBody.
  ///
  /// In en, this message translates to:
  /// **'New servers start with this key. You can change it per server.'**
  String get settingsDefaultKeyBody;

  /// No description provided for @settingsDefaultKeyNone.
  ///
  /// In en, this message translates to:
  /// **'No default'**
  String get settingsDefaultKeyNone;

  /// No description provided for @hostEditorConnection.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get hostEditorConnection;

  /// No description provided for @hostEditorConnectionHint.
  ///
  /// In en, this message translates to:
  /// **'root@192.168.1.10'**
  String get hostEditorConnectionHint;

  /// No description provided for @hostEditorConnectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste an address or a whole ssh command — user, host and port are read from it.'**
  String get hostEditorConnectionHelp;

  /// No description provided for @hostEditorConnectionInvalid.
  ///
  /// In en, this message translates to:
  /// **'That does not look like an address SSHetu can reach.'**
  String get hostEditorConnectionInvalid;

  /// No description provided for @hostEditorIdentityFileIgnored.
  ///
  /// In en, this message translates to:
  /// **'The -i path was ignored. SSHetu uses the keys it holds; choose one under Advanced options.'**
  String get hostEditorIdentityFileIgnored;

  /// No description provided for @hostsNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get hostsNewGroup;

  /// No description provided for @hostsShowNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get hostsShowNotes;

  /// No description provided for @hostsTagFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear tag filter'**
  String get hostsTagFilterClear;

  /// No description provided for @hostGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get hostGroupName;

  /// No description provided for @hostGroupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get hostGroupCreate;

  /// No description provided for @hostGroupRename.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get hostGroupRename;

  /// No description provided for @hostGroupRenameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get hostGroupRenameAction;

  /// No description provided for @hostGroupDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get hostGroupDelete;

  /// No description provided for @hostGroupDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String hostGroupDeleteConfirm(String name);

  /// No description provided for @hostGroupDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The group is removed. Its hosts are kept and move to Ungrouped.'**
  String get hostGroupDeleteBody;

  /// No description provided for @hostGroupUngrouped.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get hostGroupUngrouped;

  /// No description provided for @hostGroupEmpty.
  ///
  /// In en, this message translates to:
  /// **'No hosts in this group yet. Choose it in a host\'s editor.'**
  String get hostGroupEmpty;

  /// No description provided for @hostGroupCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse {name}'**
  String hostGroupCollapse(String name);

  /// No description provided for @hostGroupExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand {name}'**
  String hostGroupExpand(String name);

  /// No description provided for @hostEditorOrganise.
  ///
  /// In en, this message translates to:
  /// **'Organise'**
  String get hostEditorOrganise;

  /// No description provided for @hostEditorGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get hostEditorGroup;

  /// No description provided for @hostEditorGroupNone.
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get hostEditorGroupNone;

  /// No description provided for @hostEditorGroupNew.
  ///
  /// In en, this message translates to:
  /// **'New group…'**
  String get hostEditorGroupNew;

  /// No description provided for @hostEditorTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get hostEditorTags;

  /// No description provided for @hostEditorTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Type a tag, then Enter or a comma'**
  String get hostEditorTagsHint;

  /// No description provided for @hostEditorTagAdd.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get hostEditorTagAdd;

  /// No description provided for @hostEditorNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get hostEditorNotes;

  /// No description provided for @hostEditorNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Anything worth remembering about this server'**
  String get hostEditorNotesHint;

  /// No description provided for @hostEditorKeepalive.
  ///
  /// In en, this message translates to:
  /// **'Keepalive interval'**
  String get hostEditorKeepalive;

  /// No description provided for @hostEditorKeepaliveSuffix.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get hostEditorKeepaliveSuffix;

  /// No description provided for @hostEditorKeepaliveHelp.
  ///
  /// In en, this message translates to:
  /// **'0 turns keepalives off. A shorter interval keeps mobile connections from being dropped while idle.'**
  String get hostEditorKeepaliveHelp;

  /// No description provided for @hostEditorKeepaliveInvalid.
  ///
  /// In en, this message translates to:
  /// **'0–3600'**
  String get hostEditorKeepaliveInvalid;

  /// No description provided for @hostEditorFontSize.
  ///
  /// In en, this message translates to:
  /// **'Terminal font size'**
  String get hostEditorFontSize;

  /// No description provided for @hostEditorFontSizeDefault.
  ///
  /// In en, this message translates to:
  /// **'Use the app default ({size})'**
  String hostEditorFontSizeDefault(String size);

  /// No description provided for @hostEditorFontSizeHelp.
  ///
  /// In en, this message translates to:
  /// **'Zooming in the terminal changes the app default, not this host.'**
  String get hostEditorFontSizeHelp;

  /// Terminal context menu item and phone app-bar tooltip that opens the find-in-scrollback bar
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get terminalFind;

  /// No description provided for @menuFind.
  ///
  /// In en, this message translates to:
  /// **'Find…'**
  String get menuFind;

  /// No description provided for @terminalFindHint.
  ///
  /// In en, this message translates to:
  /// **'Find in scrollback'**
  String get terminalFindHint;

  /// Which search match is current, counted from the newest
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String terminalFindCount(int current, int total);

  /// Like terminalFindCount, when the search stopped at its result limit
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}+'**
  String terminalFindCountCapped(int current, int total);

  /// No description provided for @terminalFindNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get terminalFindNoMatches;

  /// No description provided for @terminalFindInvalidPattern.
  ///
  /// In en, this message translates to:
  /// **'Invalid pattern'**
  String get terminalFindInvalidPattern;

  /// No description provided for @terminalFindCaseSensitive.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get terminalFindCaseSensitive;

  /// No description provided for @terminalFindRegex.
  ///
  /// In en, this message translates to:
  /// **'Regular expression'**
  String get terminalFindRegex;

  /// No description provided for @terminalFindOlder.
  ///
  /// In en, this message translates to:
  /// **'Older match (Enter)'**
  String get terminalFindOlder;

  /// No description provided for @terminalFindNewer.
  ///
  /// In en, this message translates to:
  /// **'Newer match (Shift+Enter)'**
  String get terminalFindNewer;

  /// No description provided for @terminalFindClose.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get terminalFindClose;

  /// No description provided for @terminalOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get terminalOpenLink;

  /// No description provided for @terminalCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get terminalCopyLink;

  /// No description provided for @terminalLinkSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Open this link?'**
  String get terminalLinkSheetTitle;

  /// No description provided for @terminalLinkRefused.
  ///
  /// In en, this message translates to:
  /// **'SSHetu only opens http, https and mailto links.'**
  String get terminalLinkRefused;

  /// No description provided for @terminalLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get terminalLinkOpenFailed;

  /// No description provided for @terminalLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get terminalLinkCopied;

  /// No description provided for @pasteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste and run?'**
  String get pasteConfirmTitle;

  /// No description provided for @pasteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This text contains a line break, so pasting it will run {count, plural, =1{a command} other{commands}} at a shell prompt.'**
  String pasteConfirmBody(int count);

  /// No description provided for @pasteConfirmLineCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String pasteConfirmLineCount(int count);

  /// No description provided for @pasteConfirmMoreLines.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{…and 1 more line} other{…and {count} more lines}}'**
  String pasteConfirmMoreLines(int count);

  /// Control characters, escape sequences or invisible direction marks stripped from pasted text
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hidden character removed} other{{count} hidden characters removed}}'**
  String pasteHiddenRemoved(int count);

  /// No description provided for @pasteDontAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get pasteDontAskAgain;

  /// No description provided for @pasteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get pasteConfirmAction;

  /// No description provided for @settingsTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get settingsTerminal;

  /// No description provided for @settingsConfirmPaste.
  ///
  /// In en, this message translates to:
  /// **'Confirm multi-line paste'**
  String get settingsConfirmPaste;

  /// No description provided for @settingsConfirmPasteBody.
  ///
  /// In en, this message translates to:
  /// **'Ask before pasting text with a line break, which would run commands.'**
  String get settingsConfirmPasteBody;

  /// No description provided for @settingsKeepAlive.
  ///
  /// In en, this message translates to:
  /// **'Keep connections alive in the background'**
  String get settingsKeepAlive;

  /// No description provided for @settingsKeepAliveBody.
  ///
  /// In en, this message translates to:
  /// **'Shows a notification while sessions or tunnels are open, so Android does not close them when you switch apps.'**
  String get settingsKeepAliveBody;

  /// Android notification channel name, shown in the system's notification settings
  ///
  /// In en, this message translates to:
  /// **'Active connections'**
  String get keepAliveChannelName;

  /// No description provided for @keepAliveTitle.
  ///
  /// In en, this message translates to:
  /// **'Connections open'**
  String get keepAliveTitle;

  /// No description provided for @keepAliveSessions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String keepAliveSessions(int count);

  /// No description provided for @keepAliveTunnels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tunnel} other{{count} tunnels}}'**
  String keepAliveTunnels(int count);

  /// Notification text, e.g. '2 sessions, 1 tunnel active'
  ///
  /// In en, this message translates to:
  /// **'{sessions}, {tunnels} active'**
  String keepAliveSummaryBoth(String sessions, String tunnels);

  /// Notification text when only sessions or only tunnels are open, e.g. '1 session active'
  ///
  /// In en, this message translates to:
  /// **'{what} active'**
  String keepAliveSummaryOne(String what);

  /// No description provided for @keepAliveDisconnectAll.
  ///
  /// In en, this message translates to:
  /// **'Disconnect all'**
  String get keepAliveDisconnectAll;

  /// No description provided for @settingsKeepSessions.
  ///
  /// In en, this message translates to:
  /// **'Keep sessions running on the server'**
  String get settingsKeepSessions;

  /// No description provided for @settingsKeepSessionsBody.
  ///
  /// In en, this message translates to:
  /// **'Runs each tab inside tmux when the server has it, so a dropped connection picks up where it left off. Closing the tab ends it.'**
  String get settingsKeepSessionsBody;

  /// No description provided for @terminalNoticeConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'[connection lost — reconnecting]'**
  String get terminalNoticeConnectionLost;

  /// No description provided for @terminalNoticeSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'[session ended]'**
  String get terminalNoticeSessionEnded;

  /// No description provided for @terminalNoticeSessionClosed.
  ///
  /// In en, this message translates to:
  /// **'[session closed]'**
  String get terminalNoticeSessionClosed;

  /// No description provided for @terminalNoticeReconnected.
  ///
  /// In en, this message translates to:
  /// **'[reconnected]'**
  String get terminalNoticeReconnected;

  /// No description provided for @terminalNoticeTmuxUnavailable.
  ///
  /// In en, this message translates to:
  /// **'[tmux is not installed on this server, so this session will not survive a dropped connection]'**
  String get terminalNoticeTmuxUnavailable;

  /// No description provided for @terminalReconnectWaiting.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — reconnecting in {seconds} s (attempt {attempt})'**
  String terminalReconnectWaiting(int seconds, int attempt);

  /// No description provided for @terminalReconnectWaitingShort.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting in {seconds} s'**
  String terminalReconnectWaitingShort(int seconds);

  /// No description provided for @terminalReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get terminalReconnecting;

  /// No description provided for @terminalRetryNow.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get terminalRetryNow;

  /// No description provided for @terminalStopReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get terminalStopReconnecting;

  /// No description provided for @settingsTerminalAppearance.
  ///
  /// In en, this message translates to:
  /// **'Terminal appearance'**
  String get settingsTerminalAppearance;

  /// No description provided for @settingsTerminalTheme.
  ///
  /// In en, this message translates to:
  /// **'Terminal theme'**
  String get settingsTerminalTheme;

  /// Shown under the default terminal theme, which follows the app's light or dark mode and accent
  ///
  /// In en, this message translates to:
  /// **'Follows light and dark'**
  String get terminalThemeAdaptive;

  /// No description provided for @terminalThemeFixedDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get terminalThemeFixedDark;

  /// No description provided for @terminalThemeFixedLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get terminalThemeFixedLight;

  /// The prompt in the terminal theme preview. Looks like a user@host prompt
  ///
  /// In en, this message translates to:
  /// **'you@server'**
  String get terminalPreviewUser;

  /// A shell command in the terminal theme preview. Normally left as-is
  ///
  /// In en, this message translates to:
  /// **'ls'**
  String get terminalPreviewCommand;

  /// No description provided for @terminalPreviewDirectory.
  ///
  /// In en, this message translates to:
  /// **'docs'**
  String get terminalPreviewDirectory;

  /// No description provided for @terminalPreviewFile.
  ///
  /// In en, this message translates to:
  /// **'notes.txt'**
  String get terminalPreviewFile;

  /// No description provided for @terminalPreviewScript.
  ///
  /// In en, this message translates to:
  /// **'deploy.sh'**
  String get terminalPreviewScript;

  /// No description provided for @terminalPreviewError.
  ///
  /// In en, this message translates to:
  /// **'error: permission denied'**
  String get terminalPreviewError;

  /// No description provided for @settingsTerminalFont.
  ///
  /// In en, this message translates to:
  /// **'Terminal font'**
  String get settingsTerminalFont;

  /// No description provided for @terminalFontSystem.
  ///
  /// In en, this message translates to:
  /// **'System monospace'**
  String get terminalFontSystem;

  /// No description provided for @settingsCursorShape.
  ///
  /// In en, this message translates to:
  /// **'Cursor'**
  String get settingsCursorShape;

  /// No description provided for @cursorShapeBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get cursorShapeBlock;

  /// No description provided for @cursorShapeUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get cursorShapeUnderline;

  /// No description provided for @cursorShapeBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get cursorShapeBar;

  /// No description provided for @settingsCursorBlink.
  ///
  /// In en, this message translates to:
  /// **'Blinking cursor'**
  String get settingsCursorBlink;

  /// No description provided for @settingsCursorBlinkBody.
  ///
  /// In en, this message translates to:
  /// **'Programs such as vim can still change the cursor while they run.'**
  String get settingsCursorBlinkBody;

  /// No description provided for @settingsScrollback.
  ///
  /// In en, this message translates to:
  /// **'Scrollback'**
  String get settingsScrollback;

  /// No description provided for @settingsScrollbackValue.
  ///
  /// In en, this message translates to:
  /// **'{lines} lines · applies to new tabs'**
  String settingsScrollbackValue(int lines);

  /// No description provided for @scrollbackLinesOption.
  ///
  /// In en, this message translates to:
  /// **'{lines} lines'**
  String scrollbackLinesOption(int lines);

  /// No description provided for @hostEditorTerminalTheme.
  ///
  /// In en, this message translates to:
  /// **'Terminal theme'**
  String get hostEditorTerminalTheme;

  /// No description provided for @hostEditorTerminalThemeDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default ({name})'**
  String hostEditorTerminalThemeDefault(String name);

  /// No description provided for @terminalNoticeTmuxSessionGone.
  ///
  /// In en, this message translates to:
  /// **'[the session kept on the server has ended, so this is a new shell]'**
  String get terminalNoticeTmuxSessionGone;

  /// No description provided for @hostsRunningSessions.
  ///
  /// In en, this message translates to:
  /// **'Running sessions…'**
  String get hostsRunningSessions;

  /// No description provided for @sessionRunningSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions on this server…'**
  String get sessionRunningSessions;

  /// No description provided for @serverInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Server info'**
  String get serverInfoTitle;

  /// No description provided for @serverInfoShow.
  ///
  /// In en, this message translates to:
  /// **'Server info'**
  String get serverInfoShow;

  /// No description provided for @serverInfoHide.
  ///
  /// In en, this message translates to:
  /// **'Hide server info'**
  String get serverInfoHide;

  /// No description provided for @serverInfoClose.
  ///
  /// In en, this message translates to:
  /// **'Close server info'**
  String get serverInfoClose;

  /// No description provided for @serverInfoOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get serverInfoOverview;

  /// No description provided for @serverInfoProcesses.
  ///
  /// In en, this message translates to:
  /// **'Processes'**
  String get serverInfoProcesses;

  /// No description provided for @serverInfoHostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get serverInfoHostname;

  /// No description provided for @serverInfoSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get serverInfoSystem;

  /// No description provided for @serverInfoKernel.
  ///
  /// In en, this message translates to:
  /// **'Kernel'**
  String get serverInfoKernel;

  /// No description provided for @serverInfoUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get serverInfoUptime;

  /// No description provided for @serverInfoLoad.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get serverInfoLoad;

  /// No description provided for @serverInfoCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get serverInfoCpu;

  /// No description provided for @serverInfoCpuCores.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 core} other{{count} cores}}'**
  String serverInfoCpuCores(int count);

  /// No description provided for @serverInfoCpuHistory.
  ///
  /// In en, this message translates to:
  /// **'CPU usage over the last {count} readings'**
  String serverInfoCpuHistory(int count);

  /// No description provided for @serverInfoMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get serverInfoMemory;

  /// No description provided for @serverInfoSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get serverInfoSwap;

  /// No description provided for @serverInfoNoSwap.
  ///
  /// In en, this message translates to:
  /// **'No swap'**
  String get serverInfoNoSwap;

  /// No description provided for @serverInfoUsedOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total}'**
  String serverInfoUsedOfTotal(String used, String total);

  /// No description provided for @serverInfoFilesystems.
  ///
  /// In en, this message translates to:
  /// **'Filesystems'**
  String get serverInfoFilesystems;

  /// No description provided for @serverInfoNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get serverInfoNetwork;

  /// No description provided for @serverInfoNetDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get serverInfoNetDown;

  /// No description provided for @serverInfoNetUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get serverInfoNetUp;

  /// No description provided for @serverInfoProcessCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 process} other{{count} processes}}'**
  String serverInfoProcessCount(int count);

  /// No description provided for @serverInfoLimited.
  ///
  /// In en, this message translates to:
  /// **'Limited information on this system'**
  String get serverInfoLimited;

  /// No description provided for @serverInfoLimitedBody.
  ///
  /// In en, this message translates to:
  /// **'This server does not report CPU, memory or load in a way SSHetu can read, so only the basics are shown.'**
  String get serverInfoLimitedBody;

  /// No description provided for @serverInfoOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get serverInfoOffline;

  /// No description provided for @serverInfoOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Figures resume when the session reconnects.'**
  String get serverInfoOfflineBody;

  /// No description provided for @serverInfoError.
  ///
  /// In en, this message translates to:
  /// **'Could not read this server\'s figures: {error}'**
  String serverInfoError(String error);

  /// No description provided for @serverInfoNoSession.
  ///
  /// In en, this message translates to:
  /// **'No session selected'**
  String get serverInfoNoSession;

  /// No description provided for @serverInfoNoSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Open a terminal to see details of the server behind it.'**
  String get serverInfoNoSessionBody;

  /// No description provided for @serverInfoWaiting.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get serverInfoWaiting;

  /// No description provided for @processesFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter by name, user or PID'**
  String get processesFilter;

  /// No description provided for @processesSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get processesSortBy;

  /// No description provided for @processesSortCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get processesSortCpu;

  /// No description provided for @processesSortMem.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get processesSortMem;

  /// No description provided for @processesSortPid.
  ///
  /// In en, this message translates to:
  /// **'PID'**
  String get processesSortPid;

  /// No description provided for @processesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get processesRefresh;

  /// No description provided for @processesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No processes match'**
  String get processesEmpty;

  /// No description provided for @processesNoUsage.
  ///
  /// In en, this message translates to:
  /// **'This server\'s ps does not report CPU or memory use.'**
  String get processesNoUsage;

  /// No description provided for @processesKill.
  ///
  /// In en, this message translates to:
  /// **'Kill (SIGTERM)'**
  String get processesKill;

  /// No description provided for @processesForceKill.
  ///
  /// In en, this message translates to:
  /// **'Force kill (SIGKILL)'**
  String get processesForceKill;

  /// No description provided for @processesActions.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String processesActions(String name);

  /// No description provided for @processesKillTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop {name}?'**
  String processesKillTitle(String name);

  /// No description provided for @processesKillBody.
  ///
  /// In en, this message translates to:
  /// **'Sends SIGTERM to {name} (PID {pid}). It is asked to exit and can clean up first.'**
  String processesKillBody(String name, int pid);

  /// No description provided for @processesForceKillTitle.
  ///
  /// In en, this message translates to:
  /// **'Force kill {name}?'**
  String processesForceKillTitle(String name);

  /// No description provided for @processesForceKillBody.
  ///
  /// In en, this message translates to:
  /// **'Sends SIGKILL to {name} (PID {pid}). It stops immediately, without a chance to save anything.'**
  String processesForceKillBody(String name, int pid);

  /// No description provided for @processesKillConfirm.
  ///
  /// In en, this message translates to:
  /// **'Kill'**
  String get processesKillConfirm;

  /// No description provided for @processesForceKillConfirm.
  ///
  /// In en, this message translates to:
  /// **'Force kill'**
  String get processesForceKillConfirm;

  /// No description provided for @processesSignalSent.
  ///
  /// In en, this message translates to:
  /// **'Sent {signal} to {name} (PID {pid})'**
  String processesSignalSent(String signal, String name, int pid);

  /// No description provided for @processesSignalFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not signal {name} (PID {pid}): {error}'**
  String processesSignalFailed(String name, int pid, String error);

  /// No description provided for @processesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not list processes: {error}'**
  String processesLoadFailed(String error);

  /// No description provided for @osFamilyName.
  ///
  /// In en, this message translates to:
  /// **'{family, select, ubuntu{Ubuntu} debian{Debian} fedora{Fedora} rhel{Red Hat family} arch{Arch Linux} alpine{Alpine Linux} opensuse{openSUSE} freebsd{FreeBSD} macos{macOS} windows{Windows} linux{Linux} other{Unknown system}}'**
  String osFamilyName(String family);

  /// No description provided for @runningSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions on {host}'**
  String runningSessionsTitle(String host);

  /// No description provided for @runningSessionsIntro.
  ///
  /// In en, this message translates to:
  /// **'Shells SSHetu keeps running on this server — from this device and your others. Attach one to pick up where you left off: start something on your desktop, carry on from your phone.'**
  String get runningSessionsIntro;

  /// No description provided for @runningSessionsSharedNote.
  ///
  /// In en, this message translates to:
  /// **'Attaching a session that is open on another device shares it: both screens show the same shell, and either can type. Closing a tab attached from here leaves the session running — end it here when you are done.'**
  String get runningSessionsSharedNote;

  /// No description provided for @runningSessionsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get runningSessionsRefresh;

  /// No description provided for @runningSessionsError.
  ///
  /// In en, this message translates to:
  /// **'Could not list the sessions on this server'**
  String get runningSessionsError;

  /// No description provided for @runningSessionsNoTmux.
  ///
  /// In en, this message translates to:
  /// **'tmux is not installed on this server, so SSHetu cannot keep sessions running on it.'**
  String get runningSessionsNoTmux;

  /// No description provided for @runningSessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No SSHetu sessions are running on this server'**
  String get runningSessionsEmpty;

  /// No description provided for @runningSessionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tabs opened with “Keep sessions running on the server” turned on appear here, from any of your devices, for as long as they run.'**
  String get runningSessionsEmptyBody;

  /// No description provided for @runningSessionsThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get runningSessionsThisDevice;

  /// No description provided for @runningSessionsOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'Another device ({id})'**
  String runningSessionsOtherDevice(String id);

  /// No description provided for @runningSessionsOlder.
  ///
  /// In en, this message translates to:
  /// **'An earlier SSHetu version'**
  String get runningSessionsOlder;

  /// No description provided for @runningSessionsStarted.
  ///
  /// In en, this message translates to:
  /// **'started {age} ago'**
  String runningSessionsStarted(String age);

  /// No description provided for @runningSessionsActive.
  ///
  /// In en, this message translates to:
  /// **'active {age} ago'**
  String runningSessionsActive(String age);

  /// No description provided for @runningSessionsRunning.
  ///
  /// In en, this message translates to:
  /// **'running {command}'**
  String runningSessionsRunning(String command);

  /// No description provided for @runningSessionsAttached.
  ///
  /// In en, this message translates to:
  /// **'Attached elsewhere'**
  String get runningSessionsAttached;

  /// No description provided for @runningSessionsOpenHere.
  ///
  /// In en, this message translates to:
  /// **'Open here'**
  String get runningSessionsOpenHere;

  /// No description provided for @runningSessionsAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get runningSessionsAttach;

  /// No description provided for @runningSessionsShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get runningSessionsShow;

  /// No description provided for @runningSessionsEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get runningSessionsEnd;

  /// No description provided for @runningSessionsEndTitle.
  ///
  /// In en, this message translates to:
  /// **'End this session?'**
  String get runningSessionsEndTitle;

  /// No description provided for @runningSessionsEndBody.
  ///
  /// In en, this message translates to:
  /// **'Everything running in it on {host} stops, on every device attached to it. This cannot be undone.'**
  String runningSessionsEndBody(String host);

  /// No description provided for @runningSessionsEndFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not end the session: {error}'**
  String runningSessionsEndFailed(String error);

  /// No description provided for @runningSessionsAttachFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not attach: {error}'**
  String runningSessionsAttachFailed(String error);

  /// No description provided for @settingsReopenTabs.
  ///
  /// In en, this message translates to:
  /// **'Reopen tabs on launch'**
  String get settingsReopenTabs;

  /// No description provided for @settingsReopenTabsBody.
  ///
  /// In en, this message translates to:
  /// **'Brings back the terminal tabs that were open when SSHetu last closed, reattaching the sessions kept on the server.'**
  String get settingsReopenTabsBody;

  /// No description provided for @settingsReopenTabsAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get settingsReopenTabsAsk;

  /// No description provided for @settingsReopenTabsAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get settingsReopenTabsAlways;

  /// No description provided for @settingsReopenTabsNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get settingsReopenTabsNever;

  /// No description provided for @restoreTabsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reopen your tabs?'**
  String get restoreTabsTitle;

  /// No description provided for @restoreTabsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 terminal tab was open when SSHetu last closed: {hosts}.} other{{count} terminal tabs were open when SSHetu last closed: {hosts}.}}'**
  String restoreTabsBody(int count, String hosts);

  /// No description provided for @restoreTabsRemember.
  ///
  /// In en, this message translates to:
  /// **'Don’t ask again'**
  String get restoreTabsRemember;

  /// No description provided for @restoreTabsNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get restoreTabsNotNow;

  /// No description provided for @restoreTabsReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get restoreTabsReopen;

  /// No description provided for @hostEditorEnv.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get hostEditorEnv;

  /// No description provided for @hostEditorEnvHelp.
  ///
  /// In en, this message translates to:
  /// **'Set in every new shell on this host, exactly as typed. A session already kept on the server keeps the values it started with.'**
  String get hostEditorEnvHelp;

  /// No description provided for @hostEditorEnvName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get hostEditorEnvName;

  /// No description provided for @hostEditorEnvValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get hostEditorEnvValue;

  /// No description provided for @hostEditorEnvAdd.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get hostEditorEnvAdd;

  /// No description provided for @hostEditorEnvRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove variable'**
  String get hostEditorEnvRemove;

  /// No description provided for @hostEditorEnvMissingName.
  ///
  /// In en, this message translates to:
  /// **'Give it a name'**
  String get hostEditorEnvMissingName;

  /// No description provided for @hostEditorEnvInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Letters, digits and _ only, not starting with a digit'**
  String get hostEditorEnvInvalidName;

  /// No description provided for @hostEditorEnvDuplicateName.
  ///
  /// In en, this message translates to:
  /// **'Already set above'**
  String get hostEditorEnvDuplicateName;

  /// No description provided for @hostEditorEnvInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Cannot contain a line break'**
  String get hostEditorEnvInvalidValue;

  /// No description provided for @hostEditorForwardAgent.
  ///
  /// In en, this message translates to:
  /// **'Forward SSH agent'**
  String get hostEditorForwardAgent;

  /// No description provided for @hostEditorForwardAgentHelp.
  ///
  /// In en, this message translates to:
  /// **'Lets this server use your keys to sign in elsewhere while you\'re connected. Only enable it for servers you trust. If the server has AllowAgentForwarding disabled, the connection will fail.'**
  String get hostEditorForwardAgentHelp;

  /// No description provided for @exportJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Export as JSON (no secrets)'**
  String get exportJsonTitle;

  /// No description provided for @exportJsonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A readable file of your hosts, tunnels and snippets for other tools. Keys and passwords are left out.'**
  String get exportJsonSubtitle;

  /// No description provided for @exportJsonBody.
  ///
  /// In en, this message translates to:
  /// **'Hosts, groups, tunnels, snippets, public keys and trusted host keys, in a documented format any tool can read. Importing it back into SSHetu loses nothing.'**
  String get exportJsonBody;

  /// No description provided for @exportJsonNoSecrets.
  ///
  /// In en, this message translates to:
  /// **'Private keys, key passphrases and saved passwords are never included. To keep those too, save an encrypted backup instead.'**
  String get exportJsonNoSecrets;

  /// No description provided for @exportJsonBackupInstead.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup…'**
  String get exportJsonBackupInstead;

  /// No description provided for @exportJsonAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportJsonAction;

  /// No description provided for @exportJsonSaved.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String exportJsonSaved(String path);

  /// No description provided for @exportJsonShared.
  ///
  /// In en, this message translates to:
  /// **'Export ready to save.'**
  String get exportJsonShared;

  /// No description provided for @exportJsonFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export: {error}'**
  String exportJsonFailed(String error);

  /// No description provided for @importJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from JSON'**
  String get importJsonTitle;

  /// No description provided for @importJsonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An SSHetu JSON export. You see what will change before anything is written.'**
  String get importJsonSubtitle;

  /// No description provided for @importJsonNotJson.
  ///
  /// In en, this message translates to:
  /// **'This file is not JSON.'**
  String get importJsonNotJson;

  /// No description provided for @importJsonNotExport.
  ///
  /// In en, this message translates to:
  /// **'This is not an SSHetu export. Choose a file saved with Export as JSON.'**
  String get importJsonNotExport;

  /// No description provided for @importJsonNewer.
  ///
  /// In en, this message translates to:
  /// **'This export was written by a newer version of SSHetu (format version {version}; this build reads up to version {supported}). Update SSHetu and try again.'**
  String importJsonNewer(int version, int supported);

  /// No description provided for @importJsonInvalidVersion.
  ///
  /// In en, this message translates to:
  /// **'This export has no valid format version, so it cannot be read.'**
  String get importJsonInvalidVersion;

  /// No description provided for @importJsonMalformed.
  ///
  /// In en, this message translates to:
  /// **'This export is damaged or was edited incorrectly: {field} is missing or invalid.'**
  String importJsonMalformed(String field);

  /// No description provided for @importJsonReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read that file.'**
  String get importJsonReadFailed;

  /// No description provided for @importJsonFrom.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String importJsonFrom(String name);

  /// No description provided for @importJsonHostsNew.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new host} other{{count} new hosts}}'**
  String importJsonHostsNew(int count);

  /// No description provided for @importJsonHostsUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved host updated (same id)} other{{count} saved hosts updated (same id)}}'**
  String importJsonHostsUpdated(int count);

  /// No description provided for @importJsonHostsUnchanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 host already up to date} other{{count} hosts already up to date}}'**
  String importJsonHostsUnchanged(int count);

  /// No description provided for @importJsonConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 host matches a saved one by address} other{{count} hosts match saved ones by address}}'**
  String importJsonConflicts(int count);

  /// No description provided for @importJsonConflictsBody.
  ///
  /// In en, this message translates to:
  /// **'Same user, host and port as a saved host, but a different id — probably the same server saved on two devices.'**
  String get importJsonConflictsBody;

  /// No description provided for @importJsonMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get importJsonMerge;

  /// No description provided for @importJsonAddAsNew.
  ///
  /// In en, this message translates to:
  /// **'Add as new'**
  String get importJsonAddAsNew;

  /// No description provided for @importJsonMergeHelp.
  ///
  /// In en, this message translates to:
  /// **'The saved host takes the file\'s settings. Its tunnels and saved password stay attached.'**
  String get importJsonMergeHelp;

  /// No description provided for @importJsonAddAsNewHelp.
  ///
  /// In en, this message translates to:
  /// **'The saved host is left as it is, and the file\'s is added as a second host.'**
  String get importJsonAddAsNewHelp;

  /// No description provided for @importJsonConflictRow.
  ///
  /// In en, this message translates to:
  /// **'{incoming} → saved as {existing}'**
  String importJsonConflictRow(String incoming, String existing);

  /// No description provided for @importJsonAlso.
  ///
  /// In en, this message translates to:
  /// **'Also in this file'**
  String get importJsonAlso;

  /// No description provided for @importJsonGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups: {added} new, {updated} updated'**
  String importJsonGroups(int added, int updated);

  /// No description provided for @importJsonTunnels.
  ///
  /// In en, this message translates to:
  /// **'Tunnels: {count} to add or update'**
  String importJsonTunnels(int count);

  /// No description provided for @importJsonSnippets.
  ///
  /// In en, this message translates to:
  /// **'Snippets: {added} new, {updated} updated'**
  String importJsonSnippets(int added, int updated);

  /// No description provided for @importJsonKnownHosts.
  ///
  /// In en, this message translates to:
  /// **'Trusted host keys: {count} new'**
  String importJsonKnownHosts(int count);

  /// No description provided for @importJsonKnownHostsConflicting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 trusted host key in the file differs from the one saved here and is left out. An import never replaces a trust decision.} other{{count} trusted host keys in the file differ from the ones saved here and are left out. An import never replaces a trust decision.}}'**
  String importJsonKnownHostsConflicting(int count);

  /// No description provided for @importJsonMissingKeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Keys to bring over'**
  String get importJsonMissingKeysTitle;

  /// No description provided for @importJsonMissingKeysBody.
  ///
  /// In en, this message translates to:
  /// **'An export never contains private keys. These hosts are imported without their key until you bring it to this device — with an encrypted backup, Send to a device, or by pasting it under Keys — and choose it in the host.'**
  String get importJsonMissingKeysBody;

  /// No description provided for @importJsonMissingKeyHosts.
  ///
  /// In en, this message translates to:
  /// **'Used by: {hosts}'**
  String importJsonMissingKeyHosts(String hosts);

  /// No description provided for @importJsonNothing.
  ///
  /// In en, this message translates to:
  /// **'Everything in this file is already on this device.'**
  String get importJsonNothing;

  /// No description provided for @importJsonAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importJsonAction;

  /// No description provided for @importJsonDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {hosts} hosts, {tunnels} tunnels and {snippets} snippets'**
  String importJsonDone(int hosts, int tunnels, int snippets);

  /// No description provided for @puttyImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from PuTTY'**
  String get puttyImportTitle;

  /// No description provided for @puttyImportSubtitleWindows.
  ///
  /// In en, this message translates to:
  /// **'Saved sessions from PuTTY on this PC, or a .reg file'**
  String get puttyImportSubtitleWindows;

  /// No description provided for @puttyImportSubtitleFile.
  ///
  /// In en, this message translates to:
  /// **'From a .reg file of PuTTY sessions exported on Windows'**
  String get puttyImportSubtitleFile;

  /// No description provided for @puttyImportFile.
  ///
  /// In en, this message translates to:
  /// **'Import PuTTY .reg file'**
  String get puttyImportFile;

  /// No description provided for @puttyChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose .reg file…'**
  String get puttyChooseFile;

  /// No description provided for @puttyNoneFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No PuTTY sessions found'**
  String get puttyNoneFoundTitle;

  /// No description provided for @puttyNoneFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This Windows account has no saved PuTTY sessions. You can choose a .reg file instead: on the PC that has them, export the key HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions with regedit.'**
  String get puttyNoneFoundBody;

  /// No description provided for @puttyNoneInFile.
  ///
  /// In en, this message translates to:
  /// **'That file holds no PuTTY sessions.'**
  String get puttyNoneInFile;

  /// No description provided for @puttyReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read PuTTY sessions: {error}'**
  String puttyReadFailed(String error);

  /// No description provided for @puttySkippedProtocol.
  ///
  /// In en, this message translates to:
  /// **'Not SSH ({protocol}), so it is skipped'**
  String puttySkippedProtocol(String protocol);

  /// No description provided for @puttySkippedNoHost.
  ///
  /// In en, this message translates to:
  /// **'No host name, so it is skipped'**
  String get puttySkippedNoHost;

  /// No description provided for @puttyAlreadySaved.
  ///
  /// In en, this message translates to:
  /// **'Already saved'**
  String get puttyAlreadySaved;

  /// No description provided for @puttyNoUsername.
  ///
  /// In en, this message translates to:
  /// **'No user name saved; {name} will be used'**
  String puttyNoUsername(String name);

  /// No description provided for @puttyPpk.
  ///
  /// In en, this message translates to:
  /// **'Key not imported: {file}'**
  String puttyPpk(String file);

  /// No description provided for @puttyProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy not imported: {proxy}'**
  String puttyProxy(String proxy);

  /// No description provided for @puttyForwards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 forward becomes a tunnel, off until you review it} other{{count} forwards become tunnels, off until you review them}}'**
  String puttyForwards(int count);

  /// No description provided for @puttyInvalidForwards.
  ///
  /// In en, this message translates to:
  /// **'Forwards not understood: {list}'**
  String puttyInvalidForwards(String list);

  /// No description provided for @puttyPpkTitle.
  ///
  /// In en, this message translates to:
  /// **'PuTTY keys (.ppk) can\'t be used directly'**
  String get puttyPpkTitle;

  /// No description provided for @puttyPpkBody.
  ///
  /// In en, this message translates to:
  /// **'Convert each key with PuTTYgen: load the .ppk, then Conversions → Export OpenSSH key. Import the result under Keys and choose it in the host. Hosts that use a .ppk key: {hosts}'**
  String puttyPpkBody(String hosts);

  /// No description provided for @puttyImportAction.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Import} =1{Import 1 host} other{Import {count} hosts}}'**
  String puttyImportAction(int count);

  /// No description provided for @puttyImportDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {hosts} hosts and {tunnels} tunnels. Tunnels stay off until you review and start them.'**
  String puttyImportDone(int hosts, int tunnels);

  /// No description provided for @importMoreSources.
  ///
  /// In en, this message translates to:
  /// **'More ways to import'**
  String get importMoreSources;

  /// No description provided for @hostEditorTmuxMode.
  ///
  /// In en, this message translates to:
  /// **'Keep sessions running on this server (tmux)'**
  String get hostEditorTmuxMode;

  /// No description provided for @hostEditorTmuxModeHelp.
  ///
  /// In en, this message translates to:
  /// **'Runs each tab inside tmux, so a dropped connection picks up where it left off. Default follows the setting in Settings → Terminal.'**
  String get hostEditorTmuxModeHelp;

  /// No description provided for @hostEditorTmuxModeDefaultOn.
  ///
  /// In en, this message translates to:
  /// **'Default (currently on)'**
  String get hostEditorTmuxModeDefaultOn;

  /// No description provided for @hostEditorTmuxModeDefaultOff.
  ///
  /// In en, this message translates to:
  /// **'Default (currently off)'**
  String get hostEditorTmuxModeDefaultOff;

  /// No description provided for @hostEditorTmuxModeAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get hostEditorTmuxModeAlways;

  /// No description provided for @hostEditorTmuxModeNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get hostEditorTmuxModeNever;

  /// No description provided for @tmuxInstallPrompt.
  ///
  /// In en, this message translates to:
  /// **'tmux isn\'t installed on {host}, so this session won\'t survive a dropped connection. Install it?'**
  String tmuxInstallPrompt(String host);

  /// No description provided for @tmuxInstallCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'This command will run on the server:'**
  String get tmuxInstallCommandLabel;

  /// No description provided for @tmuxInstallCommandLabelTerminal.
  ///
  /// In en, this message translates to:
  /// **'This command will run in this terminal:'**
  String get tmuxInstallCommandLabelTerminal;

  /// No description provided for @tmuxInstallPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'sudo will ask for your password in the terminal. SSHetu never sees it.'**
  String get tmuxInstallPasswordNote;

  /// No description provided for @tmuxInstallAction.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get tmuxInstallAction;

  /// No description provided for @tmuxInstallActionTerminal.
  ///
  /// In en, this message translates to:
  /// **'Run in terminal'**
  String get tmuxInstallActionTerminal;

  /// No description provided for @tmuxInstallNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get tmuxInstallNotNow;

  /// No description provided for @tmuxInstallNever.
  ///
  /// In en, this message translates to:
  /// **'Never for this host'**
  String get tmuxInstallNever;

  /// No description provided for @tmuxInstallRunning.
  ///
  /// In en, this message translates to:
  /// **'Installing tmux on {host}…'**
  String tmuxInstallRunning(String host);

  /// No description provided for @tmuxInstallSucceeded.
  ///
  /// In en, this message translates to:
  /// **'tmux is installed. Restart this session in tmux? The shell in this tab closes, and anything running in it stops.'**
  String get tmuxInstallSucceeded;

  /// No description provided for @tmuxInstallRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart in tmux'**
  String get tmuxInstallRestart;

  /// No description provided for @tmuxInstallLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get tmuxInstallLater;

  /// No description provided for @tmuxInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Installing tmux failed:'**
  String get tmuxInstallFailed;

  /// No description provided for @tmuxInstallFailedStaleLists.
  ///
  /// In en, this message translates to:
  /// **'Installing tmux failed: the server\'s package lists are out of date. Update them and try again?'**
  String get tmuxInstallFailedStaleLists;

  /// No description provided for @tmuxInstallUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Update and install'**
  String get tmuxInstallUpdateAction;

  /// No description provided for @tmuxInstallDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get tmuxInstallDismiss;

  /// No description provided for @tmuxInstallTyped.
  ///
  /// In en, this message translates to:
  /// **'Enter your sudo password in the terminal. When the install finishes, restart this session in tmux — the shell in this tab closes, and anything running in it stops.'**
  String get tmuxInstallTyped;

  /// No description provided for @tmuxInstallUnknownManager.
  ///
  /// In en, this message translates to:
  /// **'tmux isn\'t installed on {host}, and SSHetu doesn\'t recognise its package manager. Install tmux with the server\'s own tools to keep sessions running.'**
  String tmuxInstallUnknownManager(String host);

  /// No description provided for @tmuxInstallNoPrivilege.
  ///
  /// In en, this message translates to:
  /// **'tmux isn\'t installed on {host}. Installing it needs root, and this account has no sudo. Ask the server\'s administrator to install tmux.'**
  String tmuxInstallNoPrivilege(String host);

  /// No description provided for @terminalRestartInTmux.
  ///
  /// In en, this message translates to:
  /// **'Restart in tmux'**
  String get terminalRestartInTmux;

  /// No description provided for @terminalNoticeRestartedInTmux.
  ///
  /// In en, this message translates to:
  /// **'[restarted in tmux]'**
  String get terminalNoticeRestartedInTmux;

  /// No description provided for @tmuxRestartConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart this session in tmux?'**
  String get tmuxRestartConfirmTitle;

  /// No description provided for @tmuxRestartConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The shell in this tab closes, and anything running in it stops. A new shell opens inside tmux, so it survives a dropped connection.'**
  String get tmuxRestartConfirmBody;

  /// No description provided for @tmuxRestartConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get tmuxRestartConfirmAction;

  /// No description provided for @settingsIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get settingsIntegrations;

  /// No description provided for @mcpToggle.
  ///
  /// In en, this message translates to:
  /// **'Let AI assistants use SSHetu'**
  String get mcpToggle;

  /// No description provided for @mcpToggleBody.
  ///
  /// In en, this message translates to:
  /// **'Runs a local MCP server on this computer. Assistants can read your hosts and open sessions; anything that changes something asks you first. Passwords and keys are never shared.'**
  String get mcpToggleBody;

  /// No description provided for @mcpStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get mcpStatusStarting;

  /// No description provided for @mcpStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Listening on {url}'**
  String mcpStatusRunning(String url);

  /// No description provided for @mcpStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start: {error}'**
  String mcpStatusFailed(String error);

  /// No description provided for @mcpStatusFallback.
  ///
  /// In en, this message translates to:
  /// **'Port {preferred} was busy, so {port} is used for now. Clients set up for {preferred} will not connect until it is free again.'**
  String mcpStatusFallback(int preferred, int port);

  /// No description provided for @mcpToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get mcpToken;

  /// No description provided for @mcpTokenBody.
  ///
  /// In en, this message translates to:
  /// **'Clients send this with every request. Anyone with it can ask; only you can approve.'**
  String get mcpTokenBody;

  /// No description provided for @mcpTokenShow.
  ///
  /// In en, this message translates to:
  /// **'Show token'**
  String get mcpTokenShow;

  /// No description provided for @mcpTokenHide.
  ///
  /// In en, this message translates to:
  /// **'Hide token'**
  String get mcpTokenHide;

  /// No description provided for @mcpTokenCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy token'**
  String get mcpTokenCopy;

  /// No description provided for @mcpTokenRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate token'**
  String get mcpTokenRegenerate;

  /// No description provided for @mcpTokenRegenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate the access token?'**
  String get mcpTokenRegenerateTitle;

  /// No description provided for @mcpTokenRegenerateBody.
  ///
  /// In en, this message translates to:
  /// **'Every client set up with the current token stops working until you give it the new one.'**
  String get mcpTokenRegenerateBody;

  /// No description provided for @mcpCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get mcpCopied;

  /// No description provided for @mcpSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a client'**
  String get mcpSetupTitle;

  /// No description provided for @mcpSetupClaude.
  ///
  /// In en, this message translates to:
  /// **'Claude Code'**
  String get mcpSetupClaude;

  /// No description provided for @mcpSetupJson.
  ///
  /// In en, this message translates to:
  /// **'Other clients (JSON)'**
  String get mcpSetupJson;

  /// No description provided for @mcpActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get mcpActivity;

  /// No description provided for @mcpActivityBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No calls yet} =1{1 call recorded} other{{count} calls recorded}}'**
  String mcpActivityBody(int count);

  /// No description provided for @mcpActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'MCP activity'**
  String get mcpActivityTitle;

  /// No description provided for @mcpActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No calls yet. Every call an assistant makes is listed here.'**
  String get mcpActivityEmpty;

  /// No description provided for @mcpActivityClear.
  ///
  /// In en, this message translates to:
  /// **'Clear log'**
  String get mcpActivityClear;

  /// No description provided for @mcpActivityClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the activity log?'**
  String get mcpActivityClearTitle;

  /// No description provided for @mcpActivityBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} returned'**
  String mcpActivityBytes(String size);

  /// No description provided for @mcpDecisionRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get mcpDecisionRead;

  /// No description provided for @mcpDecisionApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get mcpDecisionApproved;

  /// No description provided for @mcpDecisionRemembered.
  ///
  /// In en, this message translates to:
  /// **'Approved (remembered)'**
  String get mcpDecisionRemembered;

  /// No description provided for @mcpDecisionDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get mcpDecisionDenied;

  /// No description provided for @mcpDecisionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get mcpDecisionTimedOut;

  /// No description provided for @mcpDecisionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not shown'**
  String get mcpDecisionUnavailable;

  /// No description provided for @mcpDecisionRejected.
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get mcpDecisionRejected;

  /// No description provided for @mcpApprovalTitle.
  ///
  /// In en, this message translates to:
  /// **'{client} wants to {action}'**
  String mcpApprovalTitle(String client, String action);

  /// No description provided for @mcpActionRunCommand.
  ///
  /// In en, this message translates to:
  /// **'run a command'**
  String get mcpActionRunCommand;

  /// No description provided for @mcpActionSendInput.
  ///
  /// In en, this message translates to:
  /// **'type into a session'**
  String get mcpActionSendInput;

  /// No description provided for @mcpActionOpenSession.
  ///
  /// In en, this message translates to:
  /// **'open a session'**
  String get mcpActionOpenSession;

  /// No description provided for @mcpActionStartTunnel.
  ///
  /// In en, this message translates to:
  /// **'start a tunnel'**
  String get mcpActionStartTunnel;

  /// No description provided for @mcpActionStopTunnel.
  ///
  /// In en, this message translates to:
  /// **'stop a tunnel'**
  String get mcpActionStopTunnel;

  /// No description provided for @mcpActionRunSnippet.
  ///
  /// In en, this message translates to:
  /// **'run a snippet'**
  String get mcpActionRunSnippet;

  /// No description provided for @mcpActionDownload.
  ///
  /// In en, this message translates to:
  /// **'download a file'**
  String get mcpActionDownload;

  /// No description provided for @mcpActionUpload.
  ///
  /// In en, this message translates to:
  /// **'upload a file'**
  String get mcpActionUpload;

  /// No description provided for @mcpActionOther.
  ///
  /// In en, this message translates to:
  /// **'use {tool}'**
  String mcpActionOther(String tool);

  /// No description provided for @mcpApprovalTarget.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get mcpApprovalTarget;

  /// No description provided for @mcpApprovalNote.
  ///
  /// In en, this message translates to:
  /// **'The name is what the client calls itself. Approve only if you asked your assistant to do this.'**
  String get mcpApprovalNote;

  /// No description provided for @mcpApprovalRemember.
  ///
  /// In en, this message translates to:
  /// **'Allow this in this session for {minutes} minutes without asking'**
  String mcpApprovalRemember(int minutes);

  /// No description provided for @mcpApprovalApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get mcpApprovalApprove;

  /// No description provided for @mcpApprovalDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get mcpApprovalDeny;

  /// No description provided for @mcpDetailCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get mcpDetailCommand;

  /// No description provided for @mcpDetailInput.
  ///
  /// In en, this message translates to:
  /// **'Keystrokes'**
  String get mcpDetailInput;

  /// No description provided for @mcpDetailHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get mcpDetailHost;

  /// No description provided for @mcpDetailTunnel.
  ///
  /// In en, this message translates to:
  /// **'Tunnel'**
  String get mcpDetailTunnel;

  /// No description provided for @mcpDetailSnippet.
  ///
  /// In en, this message translates to:
  /// **'Snippet'**
  String get mcpDetailSnippet;

  /// No description provided for @mcpDetailRemotePath.
  ///
  /// In en, this message translates to:
  /// **'On the server'**
  String get mcpDetailRemotePath;

  /// No description provided for @mcpDetailLocalPath.
  ///
  /// In en, this message translates to:
  /// **'On this computer'**
  String get mcpDetailLocalPath;

  /// No description provided for @mcpDetailOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Replaces the file if it already exists'**
  String get mcpDetailOverwrite;
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
      <String>['en', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ne':
      return AppLocalizationsNe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
