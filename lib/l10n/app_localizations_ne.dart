// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class AppLocalizationsNe extends AppLocalizations {
  AppLocalizationsNe([String locale = 'ne']) : super(locale);

  @override
  String get appTitle => 'SSHetu';

  @override
  String get navHosts => 'होस्ट';

  @override
  String get navSessions => 'सेसन';

  @override
  String get navKeys => 'कुञ्जी';

  @override
  String get navTunnels => 'टनेल';

  @override
  String get navSettings => 'सेटिङ';

  @override
  String get actionRetry => 'फेरि प्रयास';

  @override
  String get actionCancel => 'रद्द गर्नुहोस्';

  @override
  String get actionConfirm => 'पुष्टि गर्नुहोस्';

  @override
  String get actionOk => 'ठिक छ';

  @override
  String get actionClose => 'बन्द गर्नुहोस्';

  @override
  String get actionShow => 'देखाउनुहोस्';

  @override
  String get actionHide => 'लुकाउनुहोस्';

  @override
  String get comingSoon => 'यहाँ अहिलेसम्म केही छैन';

  @override
  String get comingSoonBody =>
      'यो स्क्रिन प्लेसहोल्डर हो। यसलाई वास्तविक सामग्रीले बदल्नुहोस्।';

  @override
  String get settingsTitle => 'सेटिङ';

  @override
  String get settingsAppearance => 'रूप';

  @override
  String get settingsGeneral => 'सामान्य';

  @override
  String get settingsAbout => 'बारेमा';

  @override
  String get settingsAccent => 'मुख्य रङ';

  @override
  String get settingsThemeMode => 'थिम';

  @override
  String get themeSystem => 'डिभाइस अनुसार';

  @override
  String get themeLight => 'उज्यालो';

  @override
  String get themeDark => 'अँध्यारो';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get languageSystem => 'डिभाइस अनुसार';

  @override
  String get languageEnglish => 'अङ्ग्रेजी';

  @override
  String get languageNepali => 'नेपाली';

  @override
  String get settingsTextSize => 'अक्षरको आकार';

  @override
  String get textSizeSmall => 'सानो';

  @override
  String get textSizeDefault => 'पूर्वनिर्धारित';

  @override
  String get textSizeLarge => 'ठूलो';

  @override
  String get textSizeLarger => 'अझ ठूलो';

  @override
  String get settingsTerminalTextSize => 'टर्मिनलको अक्षर आकार';

  @override
  String terminalTextSizePoints(int size) {
    return '$size pt';
  }

  @override
  String get terminalTextSizeSmaller => 'अझ सानो';

  @override
  String get terminalTextSizeLarger => 'अझ ठूलो';

  @override
  String get menuZoomIn => 'जुम इन';

  @override
  String get menuZoomOut => 'जुम आउट';

  @override
  String get menuActualSize => 'वास्तविक आकार';

  @override
  String get accentIndigo => 'इन्डिगो';

  @override
  String get accentTeal => 'टिल';

  @override
  String get accentForest => 'वन हरियो';

  @override
  String get accentAmber => 'एम्बर';

  @override
  String get accentCoral => 'कोरल';

  @override
  String get accentRose => 'गुलाबी';

  @override
  String get accentMauve => 'मभ';

  @override
  String get accentSlate => 'स्लेट';

  @override
  String get aboutTitle => 'बारेमा';

  @override
  String aboutVersion(String version) {
    return 'संस्करण $version';
  }

  @override
  String get aboutPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get aboutPrivacyPolicySubtitle =>
      'हामी के सङ्कलन गर्छौं, र के गर्दैनौं';

  @override
  String get aboutLicenses => 'खुला स्रोत इजाजतपत्रहरू';

  @override
  String get aboutLicensesSubtitle =>
      'यो एपले प्रयोग गर्ने तेस्रो-पक्षीय प्याकेजहरू';

  @override
  String get aboutShare => 'SSHetu सेयर गर्नुहोस्';

  @override
  String get aboutShareSubtitle => 'उपयोगी ठान्ने कसैलाई भन्नुहोस्';

  @override
  String get aboutShareMessage =>
      'म SSHetu प्रयोग गरिरहेको छु — तपाईंलाई पनि मन पर्न सक्छ।';

  @override
  String get aboutRate => 'SSHetu लाई रेटिङ दिनुहोस्';

  @override
  String get aboutRateSubtitle => 'एउटा रेटिङले साँच्चै मद्दत गर्छ';

  @override
  String get aboutMoreApps => 'थप एपहरू';

  @override
  String get aboutMoreAppsSubtitle => 'हामीले बनाएका अन्य एपहरू';

  @override
  String get aboutSupport => 'सहायतालाई सम्पर्क गर्नुहोस्';

  @override
  String get aboutSupportSubtitle => '';

  @override
  String get aboutSupportSubject => 'SSHetu सहायता';

  @override
  String errorCouldNotOpen(String target) {
    return '$target खोल्न सकिएन';
  }

  @override
  String get updateReadyTitle => 'अपडेट डाउनलोड भयो';

  @override
  String get updateRestart => 'पुनः सुरु गर्नुहोस्';

  @override
  String get updateStuck => 'एउटा अपडेट पूरा हुन बाँकी छ';

  @override
  String get updateOpenStore => 'Play Store खोल्नुहोस्';

  @override
  String get settingsDiagnostics => 'निदान';

  @override
  String settingsDiagnosticsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'हालसालैका $count त्रुटि',
      one: 'हालसालैको 1 त्रुटि',
    );
    return '$_temp0';
  }

  @override
  String get settingsDiagnosticsNone => 'रिपोर्ट गर्नुपर्ने केही छैन';

  @override
  String get diagnosticsEmpty => 'कुनै त्रुटि रेकर्ड भएको छैन';

  @override
  String get diagnosticsEmptyBody =>
      'केही गडबड भएमा यहाँ सङ्कलन हुन्छ, ताकि तपाईं विवरण हामीलाई पठाउन सक्नुहोस्।';

  @override
  String get diagnosticsShare => 'रिपोर्ट सेयर गर्नुहोस्';

  @override
  String get diagnosticsShareSubject => 'SSHetu निदान';

  @override
  String get diagnosticsClear => 'खाली गर्नुहोस्';

  @override
  String get diagnosticsClearConfirm => 'रेकर्ड भएका सबै त्रुटि हटाउने?';

  @override
  String diagnosticsSeenTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पटक देखियो',
      one: 'एक पटक देखियो',
    );
    return '$_temp0';
  }

  @override
  String get hostsTitle => 'होस्ट';

  @override
  String get hostsEmptyTitle => 'अहिलेसम्म कुनै सर्भर छैन';

  @override
  String get hostsEmptyBody =>
      'सर्भर थप्नुहोस्, वा यो मेसिनमा पहिल्यै भएकाहरू आयात गर्नुहोस्।';

  @override
  String get hostsAdd => 'होस्ट थप्नुहोस्';

  @override
  String get hostsImport => 'OpenSSH बाट आयात';

  @override
  String get hostsSearch => 'होस्ट खोज्नुहोस्';

  @override
  String get hostsConnect => 'जडान गर्नुहोस्';

  @override
  String get hostsEdit => 'सम्पादन';

  @override
  String get hostsDelete => 'मेटाउनुहोस्';

  @override
  String get hostsDeleteConfirm => 'यो होस्ट मेटाउने?';

  @override
  String get hostsDeleteBody =>
      'यसको सेभ गरिएको पासवर्ड नष्ट हुन्छ। कुञ्जी र known-host प्रविष्टिहरू जस्ताको तस्तै रहन्छन्।';

  @override
  String get hostsNeverConnected => 'कहिल्यै जडान भएको छैन';

  @override
  String get hostEditorNew => 'नयाँ होस्ट';

  @override
  String get hostEditorEdit => 'होस्ट सम्पादन';

  @override
  String get hostEditorLabel => 'नाम';

  @override
  String get hostEditorLabelHint => 'तपाईं यसलाई के भन्नुहुन्छ — \"build box\"';

  @override
  String get hostEditorHostname => 'होस्ट';

  @override
  String get hostEditorHostnameHint => 'example.com वा 10.0.0.4';

  @override
  String get hostEditorPort => 'पोर्ट';

  @override
  String get hostEditorUsername => 'प्रयोगकर्ता नाम';

  @override
  String get hostEditorAuth => 'प्रमाणीकरण';

  @override
  String get hostEditorAuthKey => 'निजी कुञ्जी';

  @override
  String get hostEditorAuthPassword => 'पासवर्ड';

  @override
  String get hostEditorIdentity => 'कुञ्जी';

  @override
  String get hostEditorIdentityNone => 'कुनै कुञ्जी छानिएको छैन';

  @override
  String get hostEditorJump => 'यस मार्फत जडान';

  @override
  String get hostEditorJumpNone => 'सिधै';

  @override
  String get hostEditorAdvanced => 'उन्नत';

  @override
  String get hostEditorStartup => 'सुरुवाती कमान्ड';

  @override
  String get hostEditorStartupHint => 'tmux new -A -s main';

  @override
  String get hostEditorLegacy => 'पुराना (लेगेसी) एल्गोरिदमलाई अनुमति दिनुहोस्';

  @override
  String get hostEditorLegacyHelp =>
      'यो होस्टका लागि मात्र SHA-1 कुञ्जी आदानप्रदान, ssh-rsa होस्ट कुञ्जी, CBC साइफर र HMAC-MD5 लाई अनुमति दिन्छ। यी कमजोर छन् र उचित कारणले पूर्वनिर्धारितबाट हटाइएका हुन् — अरू केही नचल्ने उपकरणका लागि मात्र यो सक्रिय गर्नुहोस्, जस्तै पुरानो स्विच, राउटर वा व्यवस्थापन कन्ट्रोलर।';

  @override
  String get hostEditorSave => 'सेभ गर्नुहोस्';

  @override
  String get hostEditorRequired => 'आवश्यक छ';

  @override
  String get hostEditorPortInvalid => '1–65535';

  @override
  String get terminalConnecting => 'जडान हुँदै…';

  @override
  String get terminalDisconnect => 'जडान विच्छेद';

  @override
  String get terminalReconnect => 'पुनः जडान';

  @override
  String get terminalCloseTab => 'ट्याब बन्द गर्नुहोस्';

  @override
  String get terminalMoreActions => 'थप';

  @override
  String get sessionLogStartEllipsis => 'लग सुरु गर्नुहोस्…';

  @override
  String get sessionLogStop => 'लग रोक्नुहोस्';

  @override
  String get sessionLogKeyword => 'लग रेकर्ड सेभ आउटपुट log record save output';

  @override
  String sessionLogStartTitle(String session) {
    return '$session को लग';
  }

  @override
  String get sessionLogStartAction => 'लग सुरु गर्नुहोस्';

  @override
  String get sessionLogFormat => 'लगको ढाँचा';

  @override
  String get sessionLogFormatPlain => 'सादा टेक्स्ट';

  @override
  String get sessionLogFormatPlainHint =>
      'रङ वा नियन्त्रण कोडबिनाको पढ्न मिल्ने टेक्स्ट';

  @override
  String get sessionLogFormatRaw => 'कच्चा (रङसहित)';

  @override
  String get sessionLogFormatRawHint =>
      'जस्तो प्राप्त भयो ठ्याक्कै त्यस्तै; cat ले फेरि हेर्नुहोस्';

  @override
  String get sessionLogFormatAsciicast => 'asciicast (.cast)';

  @override
  String get sessionLogFormatAsciicastHint =>
      'समयसहितको रेकर्डिङ; asciinema ले चलाउनुहोस्';

  @override
  String get sessionLogPrivacyNote =>
      'सर्भरले देखाउने सबै कुरा फाइलमा लेखिन्छ। तपाईंले टाइप गरेको कुरा छुट्टै लग हुँदैन — सर्भरले त्यसलाई फर्काएर देखाउँछ, त्यसैले त्यो स्क्रिनमा देखिएजस्तै मात्र आउँछ। प्रम्प्टमा टाइप गरिएका पासवर्डहरू फर्काएर देखाइँदैनन्, त्यसैले ती लग हुँदैनन्।';

  @override
  String sessionLogStarted(String file) {
    return '$file मा लग हुँदैछ';
  }

  @override
  String sessionLogSaved(String file) {
    return 'लग सेभ भयो: $file';
  }

  @override
  String get sessionLogShare => 'सेयर गर्नुहोस्';

  @override
  String get sessionLogFailed => 'सेसन लग लेख्न सकिएन';

  @override
  String sessionLogIndicator(String file) {
    return '$file मा लग हुँदैछ';
  }

  @override
  String sessionLogLarge(String file) {
    return '$file 100 MB भन्दा ठूलो भइसक्यो र अझै बढ्दैछ';
  }

  @override
  String get sessionLogMarkerDisconnected => 'जडान टुट्यो';

  @override
  String get sessionLogMarkerReconnected => 'पुनः जडान भयो';

  @override
  String get sessionLogMarkerStopped => 'लग रोकियो';

  @override
  String get sessionLogMarkerTabClosed => 'ट्याब बन्द भयो';

  @override
  String get sessionLogFolder => 'सेसन लग फोल्डर';

  @override
  String get sessionLogFolderNone =>
      'छानिएको छैन — हरेक लग कहाँ सेभ गर्ने भनी सोधिन्छ';

  @override
  String get sessionLogFolderClear => 'फोल्डर हटाउनुहोस्';

  @override
  String get sessionLogAlways => 'नयाँ सेसनहरू सधैँ लग गर्नुहोस्';

  @override
  String get sessionLogAlwaysBody =>
      'हरेक नयाँ टर्मिनल ट्याबले नसोधी आफ्नो आउटपुट लग फाइलमा लेख्छ।';

  @override
  String get sessionLogAlwaysNeedsFolder =>
      'पहिले लग फोल्डर छान्नुहोस्, ताकि नसोधी लग सेभ गर्ने ठाउँ होस्।';

  @override
  String get terminalPaste => 'पेस्ट';

  @override
  String get terminalCopy => 'कपी';

  @override
  String get terminalNothingSelected =>
      'केही छानिएको छैन। टेक्स्ट छान्न टर्मिनलमा लामो थिच्नुहोस्, अनि कपी गर्नुहोस्।';

  @override
  String get sessionsEmptyTitle => 'कुनै खुला सेसन छैन';

  @override
  String get sessionsEmptyBody =>
      'कुनै होस्टमा जडान गर्नुहोस्, अनि त्यो यहाँ देखिन्छ।';

  @override
  String get hostKeyTitle => 'अपरिचित होस्ट';

  @override
  String get hostKeyTrust => 'विश्वास गरी जडान गर्नुहोस्';

  @override
  String get hostKeyChangedTitle => 'होस्टको पहिचान परिवर्तन भयो';

  @override
  String get hostKeyFingerprint => 'फिंगरप्रिन्ट';

  @override
  String get secretPasswordTitle => 'पासवर्ड';

  @override
  String get secretPassphraseTitle => 'कुञ्जीको पासफ्रेज';

  @override
  String get secretRemember => 'यो डिभाइसमा सम्झनुहोस्';

  @override
  String get secretUnlock => 'अनलक गर्नुहोस्';

  @override
  String get keysTitle => 'कुञ्जी';

  @override
  String get keysEmptyTitle => 'अहिलेसम्म कुनै कुञ्जी छैन';

  @override
  String get keysEmptyBody =>
      'तपाईंको ~/.ssh मा भएका कुञ्जीहरू आयात गर्नुहोस्, वा एउटा पेस्ट गर्नुहोस्।';

  @override
  String get keysImport => 'कुञ्जी आयात';

  @override
  String get keysGenerate => 'कुञ्जी बनाउनुहोस्';

  @override
  String get keysGenerateTitle => 'नयाँ कुञ्जी बनाउनुहोस्';

  @override
  String get keysGenerateBody =>
      'यही डिभाइसमा बनाइएको नयाँ कुञ्जी-जोडी। निजी भाग यो डिभाइसको सुरक्षित भण्डारमा रहन्छ र कहिल्यै बाहिर जाँदैन।';

  @override
  String get keysGenerateLabel => 'यो कुञ्जीको नाम राख्नुहोस्';

  @override
  String get keysGenerateDone =>
      'यो लाइन सर्भरको ~/.ssh/authorized_keys मा थप्नुहोस्:';

  @override
  String get keysCopyPublic => 'सार्वजनिक कुञ्जी कपी गर्नुहोस्';

  @override
  String get keysCopied => 'सार्वजनिक कुञ्जी कपी भयो';

  @override
  String get keysEncrypted => 'पासफ्रेजले सुरक्षित';

  @override
  String get keysDelete => 'कुञ्जी मेटाउनुहोस्';

  @override
  String get keysDeleteConfirm => 'यो कुञ्जी मेटाउने?';

  @override
  String get keysDeleteBody =>
      'निजी कुञ्जी यो डिभाइसबाट नष्ट हुन्छ र फेरि प्राप्त गर्न सकिँदैन।';

  @override
  String get keysTypeLabel => 'कुञ्जीको प्रकार';

  @override
  String get keysTypeEd25519 => 'Ed25519 (सिफारिस गरिएको)';

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
      'Ed25519 हालका सबै सर्भरमा चल्छ। कुनै सर्भर वा नीतिले माग गरेमा मात्र अर्को छान्नुहोस्।';

  @override
  String get keysPassphraseLabel => 'पासफ्रेज (ऐच्छिक)';

  @override
  String get keysPassphraseHelp =>
      'यो डिभाइसको लकमा भर पर्न खाली छोड्नुहोस्। राखेमा, जडान गर्दा यो सोधिनेछ, र यसलाई फेरि प्राप्त गर्न सकिँदैन।';

  @override
  String get keysPassphraseRepeat => 'पासफ्रेज दोहोर्‍याउनुहोस्';

  @override
  String get keysPassphraseMismatch => 'पासफ्रेजहरू मेल खाँदैनन्।';

  @override
  String get keysGenerating => 'बनाउँदै…';

  @override
  String get keysGeneratingSlow =>
      'RSA कुञ्जी बनाउँदै। यसमा केही सेकेन्ड लाग्न सक्छ।';

  @override
  String get keysGenerateFailed => 'कुञ्जी बनाउन सकिएन।';

  @override
  String get keysShare => 'सार्वजनिक कुञ्जी सेयर गर्नुहोस्';

  @override
  String get keysPaste => 'कुञ्जी पेस्ट गर्नुहोस्';

  @override
  String get paletteTitle => 'कमान्ड प्यालेट';

  @override
  String get paletteSearchHint => 'सर्भर, ट्याब, स्निपेट र कार्यहरू खोज्नुहोस्';

  @override
  String get paletteOpenTooltip => 'सबै खोज्नुहोस्';

  @override
  String get menuCommandPalette => 'कमान्ड प्यालेट…';

  @override
  String paletteNoResults(String query) {
    return '“$query” सँग केही मेल खाँदैन';
  }

  @override
  String get paletteNoResultsBody =>
      'कम अक्षर, वा होस्टनामको केही भाग प्रयोग गरी हेर्नुहोस्।';

  @override
  String get paletteEmptyTitle => 'खोज्ने कुरा अहिलेसम्म केही छैन';

  @override
  String get paletteEmptyBody =>
      'सर्भर थप्नुहोस्, अनि त्यो आफ्ना ट्याब, टनेल र स्निपेटसहित यहाँ देखिन्छ।';

  @override
  String get paletteRecent => 'हालैका';

  @override
  String get paletteKeyHint =>
      '↑↓ सार्न · Enter चलाउन · Tab अन्य कार्य · Esc बन्द गर्न';

  @override
  String get paletteCategoryHost => 'सर्भर';

  @override
  String get paletteCategorySession => 'ट्याब';

  @override
  String get paletteCategorySnippet => 'स्निपेट';

  @override
  String get paletteCategoryTunnel => 'टनेल';

  @override
  String get paletteCategorySetting => 'सेटिङ';

  @override
  String get paletteCategoryAction => 'कार्य';

  @override
  String get paletteSwitchTo => 'यसमा जानुहोस्';

  @override
  String get paletteOpenFiles => 'फाइलहरू खोल्नुहोस्';

  @override
  String get paletteTunnelStart => 'टनेल सुरु गर्नुहोस्';

  @override
  String get paletteTunnelStop => 'टनेल रोक्नुहोस्';

  @override
  String get paletteToggleTheme => 'उज्यालो र अँध्यारो थिमबीच बदल्नुहोस्';

  @override
  String paletteGoTo(String destination) {
    return '$destination मा जानुहोस्';
  }

  @override
  String paletteSettingsSection(String section) {
    return 'सेटिङ › $section';
  }

  @override
  String get keysPasteTitle => 'निजी कुञ्जी पेस्ट गर्नुहोस्';

  @override
  String get keysPasteBody =>
      'OpenSSH वा PEM निजी कुञ्जी। यो यस डिभाइसको सुरक्षित भण्डारमा राखिन्छ र कहिल्यै लग गरिँदैन।';

  @override
  String get keysPasteField => 'निजी कुञ्जी';

  @override
  String get keysPasteCheck => 'कुञ्जी जाँच्नुहोस्';

  @override
  String get keysPasteSave => 'कुञ्जी सेभ गर्नुहोस्';

  @override
  String get keysPastePassphrase => 'पासफ्रेज';

  @override
  String get keysPastePassphraseHelp =>
      'अहिले कुञ्जी पढ्न मात्र प्रयोग हुन्छ। यो सेभ हुँदैन: जडान गर्दा सोधिनेछ।';

  @override
  String get keysPasteEmpty => 'पहिले निजी कुञ्जी पेस्ट गर्नुहोस्।';

  @override
  String get keysPastePublicKey =>
      'त्यो सार्वजनिक कुञ्जी हो। बरु निजी कुञ्जी पेस्ट गर्नुहोस्: .pub नभएको फाइल, जुन -----BEGIN बाट सुरु हुन्छ।';

  @override
  String get keysPasteNotAKey => 'त्यो निजी कुञ्जीजस्तो देखिँदैन।';

  @override
  String get keysPasteUnsupported =>
      'यो कुञ्जी ढाँचा प्रयोग गर्न सकिँदैन। OpenSSH, PEM RSA र PEM EC कुञ्जीहरू समर्थित छन्; अरूलाई ssh-keygen वा PuTTYgen ले रूपान्तरण गर्नुहोस्।';

  @override
  String get keysPasteNeedsPassphrase =>
      'यो कुञ्जी सुरक्षित छ। पढ्नका लागि यसको पासफ्रेज हाल्नुहोस्।';

  @override
  String get keysPasteWrongPassphrase => 'त्यो पासफ्रेजले यो कुञ्जी खोल्दैन।';

  @override
  String get keysPasteDamaged =>
      'यो कुञ्जी बिग्रेको वा अपूर्ण छ। BEGIN र END लाइनसहित फेरि कपी गर्नुहोस्।';

  @override
  String keysPasteDuplicate(String label) {
    return 'यो कुञ्जी तपाईंसँग पहिल्यै $label नामले छ।';
  }

  @override
  String get keysPasteSaveFailed =>
      'कुञ्जी यो डिभाइसको सुरक्षित भण्डारमा सेभ गर्न सकिएन।';

  @override
  String get keysPublicKeyHeading => 'सार्वजनिक कुञ्जी';

  @override
  String get keysFingerprintHeading => 'फिंगरप्रिन्ट';

  @override
  String get importTitle => 'OpenSSH बाट आयात';

  @override
  String get importScanning => 'पहिलेको सेटअप खोज्दै…';

  @override
  String importFoundIn(String path) {
    return '$path मा भेटियो';
  }

  @override
  String get importNothingTitle => 'केही भेटिएन';

  @override
  String get importNothingBody =>
      'यो डिभाइसमा होस्ट वा कुञ्जी भएको कुनै ~/.ssh डाइरेक्टरी भेटिएन।';

  @override
  String get importUnavailableTitle => 'यहाँ उपलब्ध छैन';

  @override
  String get importUnavailableBody =>
      'यो डिभाइसमा स्क्यान गर्ने ~/.ssh छैन। बरु निजी कुञ्जी फाइल छान्नुहोस् — AirDrop वा कपी गरेर ल्याउनुहोस्, अनि यहाँ छान्नुहोस्।';

  @override
  String get importHostsSection => 'होस्ट';

  @override
  String get importKeysSection => 'कुञ्जी';

  @override
  String get importSelectAll => 'सबै छान्नुहोस्';

  @override
  String get importSelectNone => 'कुनै पनि नछान्नुहोस्';

  @override
  String importAction(int count) {
    return '$count वटा आयात गर्नुहोस्';
  }

  @override
  String importDone(int hosts, int keys) {
    return '$hosts होस्ट र $keys कुञ्जी आयात भए';
  }

  @override
  String importUnsupported(String options) {
    return 'आयात नभएका: $options';
  }

  @override
  String get importRescan => 'फेरि स्क्यान गर्नुहोस्';

  @override
  String get importNoteTitle => 'पढ्ने मात्र';

  @override
  String get importNoteBody =>
      'तपाईंका ~/.ssh फाइलहरू पढिन्छन्, कहिल्यै बदलिँदैनन्।';

  @override
  String get tunnelsEmptyTitle => 'कुनै पोर्ट फर्वार्ड छैन';

  @override
  String get tunnelsEmptyBody =>
      'कुनै होस्टको SSH जडान मार्फत त्यसको पोर्टमा पुग्न फर्वार्ड थप्नुहोस्।';

  @override
  String get importChooseFolder => 'फोल्डर छान्नुहोस्';

  @override
  String get importChooseFolderConfirm => 'यो फोल्डर पढ्नुहोस्';

  @override
  String get importChooseFolderBody =>
      'तपाईंको .ssh फोल्डर छान्नुहोस्, ताकि यसलाई पढ्न सकियोस्। यसभित्र केही पनि बदलिँदैन।';

  @override
  String get hostsNoMatches => 'कुनै होस्ट मेल खाँदैन';

  @override
  String get sessionsEmptyPickHost => 'सेसन खोल्न बायाँबाट होस्ट छान्नुहोस्।';

  @override
  String get sessionsGoToHosts => 'होस्ट छान्नुहोस्';

  @override
  String get terminalSessionEnded => 'सेसन समाप्त भयो';

  @override
  String get timeNow => 'अहिले';

  @override
  String reachabilityUp(int ms) {
    return 'पहुँचयोग्य · $ms ms';
  }

  @override
  String reachabilityDown(String reason) {
    return 'पहुँचबाहिर ($reason)';
  }

  @override
  String get reachabilityTimedOut => 'समय सकियो';

  @override
  String get reachabilityRefused => 'जडान अस्वीकार गरियो';

  @override
  String get reachabilityUnresolved => 'ठेगाना भेटिएन';

  @override
  String get reachabilityNoRoute => 'होस्टसम्म पुग्ने बाटो छैन';

  @override
  String get reachabilityUnknown => 'अहिलेसम्म जाँचिएको छैन';

  @override
  String get reachabilitySession => 'जडित · एउटा सेसन खुला छ';

  @override
  String get reachabilityCheckedNow => 'भर्खरै जाँचियो';

  @override
  String reachabilityCheckedMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनेट अघि जाँचियो',
      one: '1 मिनेट अघि जाँचियो',
    );
    return '$_temp0';
  }

  @override
  String reachabilityCheckedHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count घण्टा अघि जाँचियो',
      one: '1 घण्टा अघि जाँचियो',
    );
    return '$_temp0';
  }

  @override
  String get settingsReachability =>
      'होस्टहरू पहुँचयोग्य छन् कि छैनन् जाँच्नुहोस्';

  @override
  String get settingsReachabilityBody =>
      'होस्ट सूची स्क्रिनमा हुँदा, हरेक सर्भरको पोर्टमा छोटो समयका लागि जडान खोल्छ — कहिल्यै साइन इन गर्दैन। जडान-सीमा भएका सर्भरका लागि ढिलो-ढिलो जाँच गर्नु राम्रो हुन्छ।';

  @override
  String get settingsReachabilityOff => 'बन्द';

  @override
  String get settingsReachability30s => '30 s';

  @override
  String get settingsReachability1m => '1 मिनेट';

  @override
  String get settingsReachability5m => '5 मिनेट';

  @override
  String get hostEditorIdentityAny => 'मेरा कुनै पनि कुञ्जी';

  @override
  String get hostEditorAuthKeyHint =>
      'तपाईंका कुञ्जीहरू प्रस्ताव गर्छ, र सर्भरले अस्वीकार गरेमा पासवर्डमा फर्कन्छ — ssh जस्तै।';

  @override
  String get hostEditorAuthPasswordHint =>
      'यो होस्टलाई कहिल्यै कुञ्जी प्रस्ताव गर्दैन।';

  @override
  String get hostEditorAuthPasswordOnly => 'पासवर्ड मात्र';

  @override
  String get secretUseKeyInstead => 'बरु कुञ्जी प्रयोग गर्नुहोस्';

  @override
  String get secretPickKey => 'कुञ्जी छान्नुहोस्';

  @override
  String get secretPickKeyBody =>
      'यो कुञ्जी होस्टमा सेभ हुन्छ, त्यसैले अबदेखि यही प्रयोग हुन्छ।';

  @override
  String get secretNoKeys => 'तपाईंसँग अहिलेसम्म कुनै कुञ्जी छैन।';

  @override
  String get interactiveAuthTitle => 'सर्भर साइन-इन';

  @override
  String get interactiveAuthSubmit => 'पेस गर्नुहोस्';

  @override
  String get interactiveAuthAnswerLabel => 'उत्तर';

  @override
  String get knownHostsTitle => 'विश्वसनीय होस्ट कुञ्जीहरू';

  @override
  String get knownHostsSubtitle => 'यो डिभाइसले स्वीकार गरेका सर्भर पहिचानहरू';

  @override
  String get knownHostsEmptyTitle => 'अहिलेसम्म कुनै विश्वसनीय होस्ट छैन';

  @override
  String get knownHostsEmptyBody =>
      'तपाईंले पहिलो पटक स्वीकार गर्दा सर्भरको कुञ्जी यहाँ रेकर्ड हुन्छ।';

  @override
  String get knownHostsForget => 'यो कुञ्जी बिर्सनुहोस्';

  @override
  String get knownHostsForgetConfirm => 'यो होस्ट कुञ्जी बिर्सने?';

  @override
  String get knownHostsForgetBody =>
      'यो ठेगानामा अर्को पटक जडान गर्दा यसको कुञ्जीमा फेरि विश्वास गर्ने कि नगर्ने सोधिनेछ। सर्भर साँच्चै पुनर्निर्माण गरिएको हो भन्ने पक्का थाहा भएमा मात्र यसो गर्नुहोस् — आफैँ बदलिएको कुञ्जी भनेको बीचबाट जडान समातिँदा (interception) देखिने लक्षण हो।';

  @override
  String knownHostsTrustedOn(String date) {
    return '$date मा विश्वास गरियो';
  }

  @override
  String get knownHostsCopied => 'फिंगरप्रिन्ट कपी भयो';

  @override
  String get knownHostsImport => 'known_hosts बाट आयात';

  @override
  String get knownHostsImportTitle =>
      'विश्वसनीय होस्ट कुञ्जीहरू आयात गर्नुहोस्';

  @override
  String knownHostsImportFrom(String path) {
    return '$path बाट';
  }

  @override
  String knownHostsImportNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'विश्वास गर्नुपर्ने $count नयाँ कुञ्जी',
      one: 'विश्वास गर्नुपर्ने 1 नयाँ कुञ्जी',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportNewHashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'तीमध्ये $count को नाम ह्यास गरिएको छ। ती जस्ताको तस्तै राखिन्छन् र ती होस्टहरूमा जडान गर्दा चिनिन्छन्, तर नामद्वारा सूचीमा देखाउन सकिँदैन।',
      one: 'तीमध्ये 1 को नाम ह्यास गरिएको छ। यो जस्ताको तस्तै राखिन्छ र त्यो होस्टमा जडान गर्दा चिनिन्छ, तर नामद्वारा सूचीमा देखाउन सकिँदैन।',
    );
    return '$_temp0';
  }

  @override
  String get knownHostsImportNothing => 'आयात गर्नुपर्ने नयाँ केही छैन';

  @override
  String knownHostsImportAlready(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पहिल्यै विश्वसनीय',
      one: '1 पहिल्यै विश्वसनीय',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count होस्ट तपाईंले पहिल्यै विश्वास गरेका कुञ्जीहरूसँग बाझिन्छन्',
      one: '1 होस्ट तपाईंले पहिल्यै विश्वास गरेको कुञ्जीसँग बाझिन्छ',
    );
    return '$_temp0';
  }

  @override
  String get knownHostsImportConflictsBody =>
      'यिनलाई नबदली छोडिन्छ। कुनै सर्भर साँच्चै पुनर्निर्माण गरिएको हो भने, पहिले यहाँबाट यसको पुरानो कुञ्जी बिर्सनुहोस्, अनि फेरि आयात गर्नुहोस्।';

  @override
  String knownHostsImportTrusted(String key) {
    return 'विश्वसनीय: $key';
  }

  @override
  String knownHostsImportInFile(String key) {
    return 'फाइलमा: $key';
  }

  @override
  String get knownHostsImportSkipped => 'आयात गरिएन';

  @override
  String knownHostsImportRevoked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count @revoked लाइन — यो एपले विश्वास गरेका कुञ्जीहरू पिन गर्छ र अस्वीकार गर्ने कुञ्जीहरूको सूची राख्दैन',
      one: '1 @revoked लाइन — यो एपले विश्वास गरेका कुञ्जीहरू पिन गर्छ र अस्वीकार गर्ने कुञ्जीहरूको सूची राख्दैन',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportCertAuthority(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count @cert-authority लाइन — होस्ट प्रमाणपत्रहरू समर्थित छैनन्',
      one: '1 @cert-authority लाइन — होस्ट प्रमाणपत्रहरू समर्थित छैनन्',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportWildcards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count वाइल्डकार्ड वा निषेधित (negated) नाम — विश्वसनीय कुञ्जी ठ्याक्कै एउटा होस्टका लागि हुन्छ',
      one: '1 वाइल्डकार्ड वा निषेधित (negated) नाम — विश्वसनीय कुञ्जी ठ्याक्कै एउटा होस्टका लागि हुन्छ',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportUnsupported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'यो एपले प्रमाणित गर्न नसक्ने प्रकारका $count कुञ्जी',
      one: 'यो एपले प्रमाणित गर्न नसक्ने प्रकारको 1 कुञ्जी',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportMalformed(int count, String lines) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'पढ्न नसकिने $count लाइन ($lines)',
      one: 'पढ्न नसकिने 1 लाइन ($lines)',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportAlternates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'होस्टहरूका लागि $count अतिरिक्त कुञ्जी — प्रति होस्ट एउटा मात्र कुञ्जी राखिन्छ, जडानले पहिले प्रयोग गर्ने प्रकारको',
      one: 'एउटा होस्टका लागि 1 अतिरिक्त कुञ्जी — प्रति होस्ट एउटा मात्र कुञ्जी राखिन्छ, जडानले पहिले प्रयोग गर्ने प्रकारको',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कुञ्जी आयात गर्नुहोस्',
      one: '1 कुञ्जी आयात गर्नुहोस्',
      zero: 'आयात गर्नुहोस्',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count होस्ट कुञ्जीमा विश्वास गरियो',
      one: '1 होस्ट कुञ्जीमा विश्वास गरियो',
    );
    return '$_temp0';
  }

  @override
  String get knownHostsImportReadFailed => 'त्यो फाइल पढ्न सकिएन';

  @override
  String get knownHostsImportTooLarge =>
      'known_hosts फाइल हुनका लागि त्यो फाइल धेरै ठूलो छ';

  @override
  String get knownHostsHashedTitle => 'ह्यास गरिएको होस्ट नाम (आयातित)';

  @override
  String get settingsSecurity => 'सुरक्षा';

  @override
  String get settingsAppLock => 'सेभ गरिएका लगइन विवरणका लागि अनलक अनिवार्य';

  @override
  String get settingsAppLockBody =>
      'सेभ गरिएको पासवर्ड वा कुञ्जी प्रयोग हुनुअघि फिंगरप्रिन्ट, अनुहार वा डिभाइसको PIN ले तपाईं नै हो भनी पुष्टि गर्नुहोस्।';

  @override
  String get settingsAppLockUnavailable =>
      'पहिले यो डिभाइसमा स्क्रिन लक, फिंगरप्रिन्ट, अनुहार वा Windows Hello सेटअप गर्नुहोस्।';

  @override
  String get settingsAppLockCancelled => 'पुष्टि भएन, त्यसैले सेटिङ बदलिएन।';

  @override
  String get settingsAppLockLockedOut =>
      'धेरै पटक प्रयास भयो। आफ्नो डिभाइस अनलक गर्नुहोस्, अनि फेरि प्रयास गर्नुहोस्।';

  @override
  String get settingsAppLockFailed =>
      'यो डिभाइसले तपाईं नै हो भनी पुष्टि गर्न सकेन।';

  @override
  String get appLockEnableReason =>
      'सेभ गरिएका लगइन विवरण लक गर्न तपाईं नै हो भनी पुष्टि गर्नुहोस्';

  @override
  String get appLockDisableReason =>
      'सेभ गरिएका लगइन विवरणको लक हटाउन तपाईं नै हो भनी पुष्टि गर्नुहोस्';

  @override
  String get appLockUnlockReason => 'सेभ गरिएका SSH लगइन विवरण अनलक गर्नुहोस्';

  @override
  String get filesTitle => 'फाइलहरू';

  @override
  String get filesRemote => 'रिमोट';

  @override
  String get filesLocal => 'यो डिभाइस';

  @override
  String get filesEmptyTitle => 'यो फोल्डर खाली छ';

  @override
  String get filesNoSessionTitle => 'ब्राउज गर्ने कुनै सेसन छैन';

  @override
  String get filesNoSessionBody =>
      'पहिले टर्मिनल खोल्नुहोस्, अनि त्यहीँबाट यसका फाइलहरू खोल्नुहोस्।';

  @override
  String get filesDownload => 'डाउनलोड';

  @override
  String get filesUpload => 'अपलोड';

  @override
  String get filesUploadTitle => 'सर्भरमा अपलोड गर्नुहोस्';

  @override
  String get filesUploadAs => 'सर्भरमा यस नामले सेभ गर्नुहोस्';

  @override
  String get filesUploadFromDevice => 'डिभाइसबाट अपलोड…';

  @override
  String get filesSaveToDevice => 'डिभाइसमा सेभ गर्नुहोस्…';

  @override
  String filesUploadedName(String name) {
    return '$name अपलोड भयो';
  }

  @override
  String get filesDelete => 'मेटाउनुहोस्';

  @override
  String get filesDeleteConfirm => 'यसलाई मेटाउने?';

  @override
  String filesDeleteBody(String name) {
    return '$name स्थायी रूपमा मेटिन्छ। यसलाई पूर्ववत् गर्न सकिँदैन।';
  }

  @override
  String get filesTransferFailed => 'असफल';

  @override
  String get tunnelsAdd => 'टनेल थप्नुहोस्';

  @override
  String get tunnelsHostMissing => 'त्यो होस्ट अब छैन';

  @override
  String get tunnelsStartFailed => 'टनेल सुरु गर्न सकिएन';

  @override
  String get tunnelsDeleteConfirm => 'यो टनेल मेटाउने?';

  @override
  String get tunnelsDeleteBody => 'चलिरहेको भए यसलाई रोकिन्छ।';

  @override
  String get tunnelsStart => 'सुरु';

  @override
  String get tunnelsStop => 'रोक्नुहोस्';

  @override
  String get tunnelsEdit => 'सम्पादन';

  @override
  String get tunnelsDelete => 'मेटाउनुहोस्';

  @override
  String get tunnelStatusStopped => 'रोकिएको';

  @override
  String get tunnelStatusStarting => 'सुरु हुँदै…';

  @override
  String get tunnelStatusRunning => 'चलिरहेको';

  @override
  String get tunnelStatusFailed => 'असफल';

  @override
  String get tunnelFarEndListening => 'लक्ष्यले सुनिरहेको छ';

  @override
  String get tunnelFarEndNotListening => 'लक्ष्यमा कुनै सेवा सुनिरहेको छैन';

  @override
  String get tunnelFarEndHelp =>
      'यो स्क्रिन खुला हुँदा हरेक 30 सेकेन्डमा सर्भरबाट जाँचिन्छ।';

  @override
  String get portsTitle => 'यो सर्भरका पोर्टहरू';

  @override
  String get portsTab => 'पोर्ट';

  @override
  String get portsLoading => 'सुनिरहेका पोर्टहरू खोज्दै…';

  @override
  String get portsEmpty => 'सुनिरहेको कुनै पोर्ट भेटिएन';

  @override
  String get portsEmptyBody =>
      'यो मेसिनमा कुनै सर्भर सुरु गर्नुहोस्, अनि केही सेकेन्डमै त्यो यहाँ देखिन्छ। SSH र DNS जस्ता प्रणाली सेवाहरू देखाइँदैनन्।';

  @override
  String get portsOfflineBody => 'सेसन पुनः जडान भएपछि सूची फेरि सुरु हुन्छ।';

  @override
  String portsError(String error) {
    return 'यो सर्भरका पोर्टहरू सूचीबद्ध गर्न सकिएन: $error';
  }

  @override
  String get portsLoopbackOnly => 'यो सर्भर मात्र';

  @override
  String get portsAllInterfaces => 'सबै इन्टरफेस';

  @override
  String get portsForward => 'फर्वार्ड';

  @override
  String portsForwardTooltip(int port) {
    return 'यो डिभाइसको एउटा पोर्टलाई सर्भरको पोर्ट $port मा फर्वार्ड गर्नुहोस्';
  }

  @override
  String portsForwardFailed(int port, String error) {
    return 'पोर्ट $port फर्वार्ड गर्न सकिएन: $error';
  }

  @override
  String get portsForwardActions => 'फर्वार्डका कार्यहरू';

  @override
  String get portsOpenInBrowser => 'ब्राउजरमा खोल्नुहोस्';

  @override
  String get portsCopyAddress => 'ठेगाना कपी गर्नुहोस्';

  @override
  String portsCopied(String address) {
    return '$address कपी भयो';
  }

  @override
  String get portsSaveAsTunnel => 'टनेलका रूपमा सेभ गर्नुहोस्';

  @override
  String portsSavedAsTunnel(String label) {
    return '\"$label\" टनेलका रूपमा सेभ भयो';
  }

  @override
  String get portsStopForward => 'फर्वार्ड रोक्नुहोस्';

  @override
  String get settingsStartTunnelsAtLaunch =>
      'SSHetu खुल्दा स्वतः-सुरु टनेलहरू सुरु गर्नुहोस्';

  @override
  String get settingsStartTunnelsAtLaunchBody =>
      'स्वतः सुरु हुने गरी सेट गरिएका टनेलहरू आफ्नो सर्भरमा टर्मिनल खुल्ने प्रतीक्षा नगरी एप खुल्नेबित्तिकै जडान हुन्छन्। त्यसपछि SSHetu ले ती सर्भरहरूमा पहिले नसोधी जडान गर्छ।';

  @override
  String tunnelActiveConnections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सक्रिय',
      one: '1 सक्रिय',
    );
    return '$_temp0';
  }

  @override
  String get tunnelNotLoopbackShort => 'नेटवर्कमा खुला';

  @override
  String get tunnelEditorNew => 'नयाँ टनेल';

  @override
  String get tunnelEditorEdit => 'टनेल सम्पादन';

  @override
  String get tunnelEditorHost => 'होस्ट';

  @override
  String get tunnelEditorLabel => 'नाम';

  @override
  String get tunnelEditorLabelHint =>
      'तपाईं यसलाई के भन्नुहुन्छ — \"prod database\"';

  @override
  String get tunnelEditorKind => 'प्रकार';

  @override
  String get tunnelKindLocal => 'लोकल';

  @override
  String get tunnelKindRemote => 'रिमोट';

  @override
  String get tunnelKindSocks => 'डाइनामिक';

  @override
  String get tunnelKindLocalHint =>
      'यो डिभाइसको पोर्टलाई SSH जडान मार्फत लक्ष्यमा फर्वार्ड गर्छ — ssh -L जस्तै।';

  @override
  String get tunnelKindRemoteHint =>
      'सर्भरलाई यसको एउटा पोर्ट यहाँबाट पुग्न सकिने लक्ष्यतर्फ फर्काएर फर्वार्ड गर्न भन्छ — ssh -R जस्तै।';

  @override
  String get tunnelKindSocksHint =>
      'निश्चित लक्ष्य नभएको लोकल SOCKS5 प्रोक्सी — ssh -D जस्तै। कुनै एपको प्रोक्सी सेटिङ यसमा राख्नुहोस्।';

  @override
  String get tunnelEditorListen => 'सुन्ने';

  @override
  String get tunnelEditorListenHost => 'ठेगाना';

  @override
  String get tunnelEditorPort => 'पोर्ट';

  @override
  String get tunnelEditorNotLoopback =>
      '127.0.0.1 बाहेक अरू कुनै ठेगानामा बाँध्दा यो फर्वार्ड सम्पूर्ण नेटवर्कमा खुला हुन्छ।';

  @override
  String get tunnelEditorTarget => 'लक्ष्य';

  @override
  String get tunnelEditorTargetHost => 'होस्ट';

  @override
  String get tunnelEditorTargetHostHint => 'example.com वा 10.0.0.4';

  @override
  String get tunnelEditorAutoStart => 'स्वतः सुरु गर्नुहोस्';

  @override
  String get tunnelEditorAutoStartHint =>
      'यो होस्टमा टर्मिनल खोल्दा सुरु हुन्छ।';

  @override
  String get tunnelWhat => 'तपाईं के गर्न चाहनुहुन्छ?';

  @override
  String get tunnelLocalPlain => 'सर्भरमा भएको कुरामा पुग्नुहोस्';

  @override
  String get tunnelLocalPlainBody =>
      'सर्भरमा चलिरहेको डाटाबेस वा वेब एप यो डिभाइसमा उपलब्ध हुन्छ।';

  @override
  String get tunnelRemotePlain => 'सर्भरलाई यो डिभाइससम्म पुग्न दिनुहोस्';

  @override
  String get tunnelRemotePlainBody =>
      'यो डिभाइसमा चलिरहेको कुरा सर्भरमा उपलब्ध हुन्छ।';

  @override
  String get tunnelSocksPlain => 'ट्राफिक सर्भर मार्फत पठाउनुहोस्';

  @override
  String get tunnelSocksPlainBody =>
      'यो डिभाइसमा एउटा SOCKS प्रोक्सी, ताकि यसमा जोडिएका एपहरूले सर्भरबाटै ब्राउज गरेजस्तो गर्छन्।';

  @override
  String get tunnelPortHere => 'यो डिभाइसको पोर्ट';

  @override
  String get tunnelPortThere => 'सर्भरको पोर्ट';

  @override
  String get tunnelServiceThere => 'सर्भरको कुन सेवा';

  @override
  String get tunnelServiceHere => 'यो डिभाइसको कुन सेवा';

  @override
  String get tunnelAddressField => 'ठेगाना';

  @override
  String get tunnelPortField => 'पोर्ट';

  @override
  String tunnelPreviewLocal(String listen, String target, String server) {
    return 'यो डिभाइसमा $listen खोल्नुहोस्, अनि तपाईं $server को $target मा पुग्नुहुन्छ।';
  }

  @override
  String tunnelPreviewRemote(String listen, String server, String target) {
    return '$server मा $listen खोल्नुहोस्, अनि त्यो यो डिभाइसको $target मा पुग्छ।';
  }

  @override
  String tunnelPreviewSocks(String listen, String server) {
    return 'कुनै एपलाई $listen मा SOCKS5 प्रोक्सीका रूपमा जोड्नुहोस्, अनि त्यसको ट्राफिक $server बाट बाहिरिन्छ।';
  }

  @override
  String get tunnelAdvanced => 'उन्नत';

  @override
  String get tunnelNameOptional => 'नाम (ऐच्छिक)';

  @override
  String get tunnelNameHint => 'खाली छोडे, पोर्टहरूका आधारमा नाम राखिन्छ';

  @override
  String get tunnelBindHere => 'यो डिभाइसमा सुन्ने ठेगाना';

  @override
  String get tunnelBindThere => 'सर्भरमा सुन्ने ठेगाना';

  @override
  String get tunnelPreviewServerFallback => 'सर्भर';

  @override
  String get actionCopy => 'कपी';

  @override
  String get actionPaste => 'पेस्ट';

  @override
  String get actionSelectAll => 'सबै छान्नुहोस्';

  @override
  String get actionClear => 'स्क्रोलब्याक खाली गर्नुहोस्';

  @override
  String get sessionDisconnect => 'जडान विच्छेद';

  @override
  String get sessionCloseOthers => 'अन्य ट्याबहरू बन्द गर्नुहोस्';

  @override
  String get filesTransferCancelled => 'रद्द गरियो';

  @override
  String get filesPathEdit => 'पाथ सम्पादन';

  @override
  String get filesPathHint => 'पूर्ण पाथ लेख्नुहोस्';

  @override
  String get filesPathNotAbsolute =>
      '/ वा ~ बाट सुरु हुने पूर्ण पाथ लेख्नुहोस्';

  @override
  String get filesPathNotFound => 'यस्तो पाथ छैन';

  @override
  String get filesPathNotADirectory => 'त्यो फाइल हो, फोल्डर होइन';

  @override
  String get filesPathOutsideSandbox => 'यो डिभाइसमा एपको भण्डारभन्दा बाहिर';

  @override
  String get filesPathFailed => 'त्यो पाथ जाँच्न सकिएन';

  @override
  String get filesPermissionDeniedTitle => 'अनुमति अस्वीकृत';

  @override
  String filesPermissionDeniedBody(String path) {
    return 'तपाईंलाई $path मा पहुँच छैन।';
  }

  @override
  String get filesNotFoundTitle => 'भेटिएन';

  @override
  String filesNotFoundBody(String path) {
    return '$path अब अस्तित्वमा छैन।';
  }

  @override
  String get filesSandboxNotice =>
      'यो डिभाइसमा यो एपको आफ्नै भण्डारमा सीमित — iOS वा Android कुनैले पनि थप अनुमतिबिना एपलाई बाँकी फाइल सिस्टम ब्राउज गर्न दिँदैन, र यो एपले त्यस्तो अनुमति माग्दैन।';

  @override
  String get filesChmod => 'अनुमतिहरू बदल्नुहोस्';

  @override
  String get filesChmodOwner => 'मालिक';

  @override
  String get filesChmodGroup => 'समूह';

  @override
  String get filesChmodOther => 'अन्य';

  @override
  String get filesChmodRead => 'पढ्ने';

  @override
  String get filesChmodWrite => 'लेख्ने';

  @override
  String get filesChmodExecute => 'चलाउने';

  @override
  String get filesChmodOctalLabel => 'अक्टल';

  @override
  String get filesChmodOctalInvalid =>
      '1-4 अक्टल अङ्क लेख्नुहोस्, प्रत्येक 0-7';

  @override
  String get filesChmodApply => 'लागू गर्नुहोस्';

  @override
  String get filesShowHidden => 'लुकेका फाइलहरू देखाउनुहोस्';

  @override
  String get filesHideHidden => 'लुकेका फाइलहरू लुकाउनुहोस्';

  @override
  String get filesSortBy => 'क्रमबद्ध गर्ने आधार';

  @override
  String get filesSortName => 'नाम';

  @override
  String get filesSortSize => 'आकार';

  @override
  String get filesSortModified => 'परिमार्जित';

  @override
  String get filesSelect => 'छान्नुहोस्';

  @override
  String get filesSelectAll => 'सबै छान्नुहोस्';

  @override
  String filesSelectionCount(int count) {
    return '$count छानिए';
  }

  @override
  String get filesDownloadSelected => 'छानिएका डाउनलोड गर्नुहोस्';

  @override
  String get filesUploadSelected => 'छानिएका अपलोड गर्नुहोस्';

  @override
  String get filesDeleteSelected => 'छानिएका मेटाउनुहोस्';

  @override
  String filesDeleteSelectedBody(int count) {
    return '$count वटा वस्तु स्थायी रूपमा मेटिन्छन्। यसलाई पूर्ववत् गर्न सकिँदैन।';
  }

  @override
  String get filesRename => 'नाम बदल्नुहोस्';

  @override
  String get filesNewFolder => 'नयाँ फोल्डर';

  @override
  String get filesCreate => 'बनाउनुहोस्';

  @override
  String get filesNameLabel => 'नाम';

  @override
  String get filesNameEmpty => 'नाम लेख्नुहोस्';

  @override
  String get filesNameSeparator => 'नाममा / जस्तो पाथ विभाजक हुन सक्दैन';

  @override
  String get filesNameReserved =>
      '“.” र “..” आरक्षित छन्, नामका रूपमा प्रयोग गर्न सकिँदैन';

  @override
  String filesNameExists(String name) {
    return '$name नामको कुरा यहाँ पहिल्यै छ';
  }

  @override
  String get filesActionFailed => 'त्यो काम भएन। विवरण सेटिङ → निदानमा छ।';

  @override
  String get filesConflictTitle => 'केही फाइलहरू त्यहाँ पहिल्यै छन्';

  @override
  String filesConflictBody(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name का $count फाइल गन्तव्यमा पहिल्यै छन्।',
      one: '$name को 1 फाइल गन्तव्यमा पहिल्यै छ।',
    );
    return '$_temp0 यो छनोट ती सबैमा लागू हुन्छ।';
  }

  @override
  String get filesConflictOverwrite => 'ओभरराइट गर्नुहोस्';

  @override
  String get filesConflictSkip => 'भइरहेकालाई छोड्नुहोस्';

  @override
  String get filesEdit => 'सम्पादन';

  @override
  String filesDropUpload(String folder) {
    return '$folder मा अपलोड गर्न यहाँ छोड्नुहोस्';
  }

  @override
  String filesDropDownload(String folder) {
    return '$folder मा डाउनलोड गर्न यहाँ छोड्नुहोस्';
  }

  @override
  String filesDragCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count वस्तु',
      one: '1 वस्तु',
    );
    return '$_temp0';
  }

  @override
  String get editorRevert => 'सेभ गरिएको संस्करणमा फर्कनुहोस्';

  @override
  String editorSaveTooltip(String keys) {
    return 'सेभ ($keys)';
  }

  @override
  String get editorUnsaved => 'सेभ नगरिएका परिवर्तन';

  @override
  String editorSaved(String name) {
    return '$name सेभ भयो';
  }

  @override
  String editorReloaded(String name) {
    return '$name सर्भरबाट फेरि लोड गरियो';
  }

  @override
  String get editorUtf8 => 'UTF-8';

  @override
  String get editorUtf8Bom => 'BOM सहित UTF-8';

  @override
  String get editorLf => 'LF';

  @override
  String get editorCrlf => 'CRLF';

  @override
  String get editorMixedEndings => 'मिश्रित लाइन-अन्त्य, जस्ताको तस्तै राखिएको';

  @override
  String get editorTooLargeTitle => 'यहाँ सम्पादन गर्न धेरै ठूलो';

  @override
  String editorTooLargeBody(String name, String limit) {
    return '$name $limit भन्दा ठूलो छ। बरु यसलाई डाउनलोड गरी यो डिभाइसको कुनै एडिटरमा खोल्नुहोस्।';
  }

  @override
  String get editorBinaryTitle => 'टेक्स्ट फाइल होइन';

  @override
  String editorBinaryBody(String name) {
    return '$name मा बाइनरी डाटा छ, त्यसैले यसलाई टेक्स्टका रूपमा सम्पादन गर्न सकिँदैन।';
  }

  @override
  String get editorNotUtf8Title => 'UTF-8 टेक्स्ट होइन';

  @override
  String editorNotUtf8Body(String name) {
    return '$name मान्य UTF-8 होइन। यहाँबाट सेभ गर्दा तपाईंले नछोएका अक्षरहरू पनि बदलिन सक्छन्, त्यसैले यो खोलिँदैन।';
  }

  @override
  String get editorNotAFileTitle => 'फाइल होइन';

  @override
  String editorNotAFileBody(String name) {
    return '$name एउटा फोल्डर हो।';
  }

  @override
  String get editorLoadFailedTitle => 'फाइल खोल्न सकिएन';

  @override
  String get editorConflictTitle => 'सर्भरमा परिवर्तन भयो';

  @override
  String editorConflictBody(String name) {
    return 'तपाईंले खोलेपछि $name सर्भरमा परिवर्तन भयो। त्यो परिवर्तनमाथि आफ्नो ओभरराइट गर्नुहोस्, आफ्ना सम्पादन गुमाएर सर्भरको संस्करण फेरि लोड गर्नुहोस्, वा रद्द गरी पछि निर्णय गर्नुहोस्।';
  }

  @override
  String get editorConflictOverwrite => 'ओभरराइट';

  @override
  String get editorConflictReload => 'फेरि लोड';

  @override
  String get editorDiscardTitle => 'सेभ नगरिएका परिवर्तन खारेज गर्ने?';

  @override
  String editorDiscardBody(String name) {
    return '$name मा गरिएका तपाईंका सम्पादन सेभ भएका छैनन्।';
  }

  @override
  String get editorDiscard => 'खारेज गर्नुहोस्';

  @override
  String get filesFolderPreparing => 'तयारी हुँदै…';

  @override
  String filesFolderProgress(int done, int total) {
    return '$total मध्ये $done फाइल';
  }

  @override
  String filesFolderTransferred(int done, int total) {
    return '$total मध्ये $done फाइल स्थानान्तरण भए';
  }

  @override
  String filesFolderSkipped(int count) {
    return '$count छोडियो (लिङ्क वा धेरै गहिरो)';
  }

  @override
  String filesFolderExistingSkipped(int count) {
    return '$count पहिल्यै त्यहाँ छन्';
  }

  @override
  String get importPickKeyFile => 'कुञ्जी फाइल छान्नुहोस्';

  @override
  String importKeyAdded(String label) {
    return '$label थपियो';
  }

  @override
  String get importNotAKey => 'त्यो फाइल निजी कुञ्जी होइन।';

  @override
  String get importNoteBodyMobile =>
      'यो डिभाइसको फाइलबाट निजी कुञ्जी थप्नुहोस्।';

  @override
  String get transferTitle => 'अर्को डिभाइसमा सार्नुहोस्';

  @override
  String get transferBody =>
      'तपाईंका सर्भर, कुञ्जी र टनेलहरू उही नेटवर्कमा भएको अर्को डिभाइसमा सिधै पठाउनुहोस्। केही पनि कुनै सर्भर हुँदै जाँदैन, र दुई डिभाइसबाहेक कतै पनि केही राखिँदैन।';

  @override
  String get transferSend => 'डिभाइसमा पठाउनुहोस्';

  @override
  String get transferReceive => 'डिभाइसबाट प्राप्त गर्नुहोस्';

  @override
  String get transferSendTitle => 'अर्को डिभाइसबाट यो स्क्यान गर्नुहोस्';

  @override
  String get transferSendBody =>
      'अर्को डिभाइसमा SSHetu खोल्नुहोस्, “डिभाइसबाट प्राप्त गर्नुहोस्” छान्नुहोस्, र यो कोडतर्फ देखाउनुहोस्।';

  @override
  String get transferIncludeSecrets => 'कुञ्जी र पासवर्डहरू समावेश गर्नुहोस्';

  @override
  String get transferIncludeSecretsBody =>
      'सर्भरहरूको सूची मात्र होइन, निजी कुञ्जी र सेभ गरिएका पासवर्डहरू नै पठाउँछ।';

  @override
  String get transferWaiting => 'अर्को डिभाइसको प्रतीक्षा गर्दै…';

  @override
  String transferSentTo(String device) {
    return '$device मा पठाइयो';
  }

  @override
  String get transferReceiveTitle => 'अर्को डिभाइसको कोड स्क्यान गर्नुहोस्';

  @override
  String get transferReceiveBody =>
      'तपाईंका सर्भरहरू भएको डिभाइसमा “अर्को डिभाइसमा सार्नुहोस्” छान्नुहोस्, अनि “डिभाइसमा पठाउनुहोस्”।';

  @override
  String get transferPasteInstead => 'बरु कोड पेस्ट गर्नुहोस्';

  @override
  String get transferPasteHint => 'sshetu://transfer/…';

  @override
  String get transferOfferTitle => 'यो स्थानान्तरण स्वीकार गर्ने?';

  @override
  String transferOfferFrom(String device) {
    return '$device बाट';
  }

  @override
  String transferOfferHosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सर्भर',
      one: '1 सर्भर',
      zero: 'कुनै सर्भर छैन',
    );
    return '$_temp0';
  }

  @override
  String transferOfferKeys(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कुञ्जी',
      one: '1 कुञ्जी',
      zero: 'कुनै कुञ्जी छैन',
    );
    return '$_temp0';
  }

  @override
  String transferOfferTunnels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count टनेल',
      one: '1 टनेल',
      zero: 'कुनै टनेल छैन',
    );
    return '$_temp0';
  }

  @override
  String transferOfferTrusted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count विश्वसनीय होस्ट कुञ्जी',
      one: '1 विश्वसनीय होस्ट कुञ्जी',
      zero: 'कुनै विश्वसनीय होस्ट कुञ्जी छैन',
    );
    return '$_temp0';
  }

  @override
  String get transferOfferSecrets =>
      'निजी कुञ्जी र सेभ गरिएका पासवर्डहरू समावेश छन्';

  @override
  String get transferOfferNoSecrets => 'कुनै कुञ्जी वा पासवर्ड समावेश छैन';

  @override
  String get transferOfferReplaces =>
      'यो डिभाइसमा पहिल्यै भएका उही नामका कुराहरू बदलिन्छन्।';

  @override
  String get transferAccept => 'स्वीकार गर्नुहोस्';

  @override
  String transferReceived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सर्भर प्राप्त भए',
      one: '1 सर्भर प्राप्त भयो',
    );
    return '$_temp0';
  }

  @override
  String get transferScanAgain => 'फेरि स्क्यान गर्नुहोस्';

  @override
  String get transferCameraDenied =>
      'कोड स्क्यान गर्न SSHetu लाई क्यामेरा चाहिन्छ। बरु तपाईं कोडलाई टेक्स्टका रूपमा पेस्ट गर्न सक्नुहुन्छ।';

  @override
  String get transferCopyCode => 'कोड कपी गर्नुहोस्';

  @override
  String get transferCodeCopied =>
      'कोड कपी भयो। अर्को डिभाइसमा पेस्ट गर्नुहोस्।';

  @override
  String get transferScanCode => 'कोड स्क्यान गर्नुहोस्';

  @override
  String get menuFile => 'फाइल';

  @override
  String get menuView => 'दृश्य';

  @override
  String get menuSession => 'सेसन';

  @override
  String get menuHelp => 'मद्दत';

  @override
  String get menuNewHost => 'नयाँ सर्भर…';

  @override
  String get menuImport => 'OpenSSH बाट आयात…';

  @override
  String get menuGenerateKey => 'कुञ्जी बनाउनुहोस्…';

  @override
  String get menuSendToDevice => 'डिभाइसमा पठाउनुहोस्…';

  @override
  String get menuReceiveFromDevice => 'डिभाइसबाट प्राप्त गर्नुहोस्…';

  @override
  String get menuCloseSession => 'सेसन बन्द गर्नुहोस्';

  @override
  String get menuNextSession => 'अर्को सेसन';

  @override
  String get menuPreviousSession => 'अघिल्लो सेसन';

  @override
  String get menuSplitRight => 'दायाँतिर विभाजन';

  @override
  String get menuSplitDown => 'तलतिर विभाजन';

  @override
  String get menuClosePane => 'प्यान बन्द गर्नुहोस्';

  @override
  String get menuNextPane => 'अर्को प्यान';

  @override
  String get menuPreviousPane => 'अघिल्लो प्यान';

  @override
  String get menuMaximizePane => 'प्यान ठूलो बनाउनुहोस्';

  @override
  String get menuTypeInAllPanes => 'सबै प्यानमा टाइप गर्नुहोस्';

  @override
  String get menuStopTypingInAllPanes => 'सबै प्यानमा टाइप गर्न रोक्नुहोस्';

  @override
  String get paneSplitRight => 'दायाँतिर विभाजन';

  @override
  String get paneSplitDown => 'तलतिर विभाजन';

  @override
  String get paneClose => 'प्यान बन्द गर्नुहोस्';

  @override
  String get paneMaximize => 'प्यान ठूलो बनाउनुहोस्';

  @override
  String get paneRestore => 'प्यान पहिलेजस्तै बनाउनुहोस्';

  @override
  String get paneTypeInAll => 'सबै प्यानमा टाइप गर्नुहोस्';

  @override
  String get paneStopTypingInAll => 'सबै प्यानमा टाइप गर्न रोक्नुहोस्';

  @override
  String paneBroadcastBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'सबै प्यानमा टाइप हुँदै · अन्य $count प्यानले पनि यो प्राप्त गर्छन्',
      one: 'सबै प्यानमा टाइप हुँदै · अर्को 1 प्यानले पनि यो प्राप्त गर्छ',
    );
    return '$_temp0';
  }

  @override
  String get paneBroadcastReceiving =>
      'कुनै पनि प्यानमा टाइप गरिएको कुरा प्राप्त गर्छ';

  @override
  String get paneBroadcastExcluded => 'सबै प्यानमा टाइपबाट बाहिर राखिएको';

  @override
  String get paneBroadcastExclude => 'यो प्यान बाहिर राख्नुहोस्';

  @override
  String get paneBroadcastInclude => 'यो प्यान समावेश गर्नुहोस्';

  @override
  String get paneBroadcastStop => 'रोक्नुहोस्';

  @override
  String get paneSwitcherLabel => 'यो ट्याबका प्यानहरू';

  @override
  String paneCount(int count) {
    return '$count प्यान';
  }

  @override
  String get menuHosts => 'सर्भरहरू';

  @override
  String get menuKeys => 'कुञ्जीहरू';

  @override
  String get menuTunnels => 'टनेलहरू';

  @override
  String get menuSnippets => 'स्निपेटहरू';

  @override
  String get menuSnippetsEllipsis => 'स्निपेटहरू…';

  @override
  String get navSnippets => 'स्निपेट';

  @override
  String get snippetsAdd => 'नयाँ स्निपेट';

  @override
  String get snippetsSearch => 'स्निपेट खोज्नुहोस्';

  @override
  String get snippetsEmptyTitle => 'अहिलेसम्म कुनै स्निपेट छैन';

  @override
  String snippetsEmptyBody(String example) {
    return 'प्रायः टाइप गर्ने कमान्डहरू सेभ गर्नुहोस्, अनि कुनै पनि सेसनमा हाल्नुहोस् वा चलाउनुहोस्। हरेक पटक भर्नुपर्ने मानका लागि $example प्रयोग गर्नुहोस्।';
  }

  @override
  String get snippetsNoMatch => 'कुनै स्निपेट मेल खाँदैन';

  @override
  String get snippetsEdit => 'सम्पादन';

  @override
  String get snippetsDelete => 'मेटाउनुहोस्';

  @override
  String get snippetsMore => 'थप';

  @override
  String get snippetsDeleteConfirm => 'यो स्निपेट मेटाउने?';

  @override
  String get snippetsNoSession =>
      'पहिले सेसन खोल्नुहोस् — स्निपेटलाई पठाउने ठाउँ चाहिन्छ।';

  @override
  String get snippetCopy => 'कमान्ड कपी गर्नुहोस्';

  @override
  String get snippetCopied => 'कमान्ड कपी भयो';

  @override
  String get snippetEditorNew => 'नयाँ स्निपेट';

  @override
  String get snippetEditorEdit => 'स्निपेट सम्पादन';

  @override
  String get snippetEditorLabel => 'नाम';

  @override
  String get snippetEditorLabelHint => 'nginx पुनः सुरु गर्नुहोस्';

  @override
  String get snippetEditorBody => 'कमान्ड';

  @override
  String snippetEditorBodyHint(String example) {
    return 'उदाहरण: $example';
  }

  @override
  String get snippetEditorDescription => 'विवरण (ऐच्छिक)';

  @override
  String get snippetEditorTags => 'ट्यागहरू';

  @override
  String snippetEditorVariablesHint(
    String ask,
    String prefilled,
    String builtins,
  ) {
    return '$ask ले प्रयोग गर्दा मान सोध्छ, $prefilled ले पहिले नै भरिदिन्छ। $builtins सेसनबाट आउँछन्।';
  }

  @override
  String snippetEditorAsks(String names) {
    return 'सोध्छ: $names';
  }

  @override
  String snippetEditorFills(String names) {
    return 'भर्छ: $names';
  }

  @override
  String snippetPickerTitle(String session) {
    return 'स्निपेट · $session';
  }

  @override
  String get snippetPickerManage => 'स्निपेटहरू व्यवस्थापन';

  @override
  String get snippetInsert => 'हाल्नुहोस्';

  @override
  String get snippetRun => 'चलाउनुहोस्';

  @override
  String get snippetRunOn => 'यसमा चलाउनुहोस्…';

  @override
  String get snippetRunOnTitle => 'कुन सेसनहरूमा चलाउने?';

  @override
  String get snippetRunOnAll => 'जडित सबै सेसन';

  @override
  String get snippetRunOnNotConnected => 'जडान छैन';

  @override
  String snippetRunOnConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेसनमा चलाउनुहोस्',
      one: '1 सेसनमा चलाउनुहोस्',
    );
    return '$_temp0';
  }

  @override
  String get snippetVariablesTitle => 'स्निपेट भर्नुहोस्';

  @override
  String get snippetVariablesPreview => 'टाइप हुनेछ';

  @override
  String get snippetNotConnected => 'यो सेसन जडित छैन, त्यसैले केही टाइप भएन।';

  @override
  String get snippetEmpty => 'त्यो स्निपेटमा टाइप गर्ने केही छैन।';

  @override
  String get snippetMultilineInsertRefused =>
      'यो शेलले हरेक लाइन आइपुग्नेबित्तिकै चलाउँछ, त्यसैले स्निपेट हालिएन। बरु “चलाउनुहोस्” प्रयोग गर्नुहोस्।';

  @override
  String snippetRanIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेसनमा चलाइयो',
      one: '1 सेसनमा चलाइयो',
    );
    return '$_temp0';
  }

  @override
  String snippetRanInSome(int sent, int total) {
    return '$total मध्ये $sent सेसनमा चलाइयो — बाँकी जडित थिएनन्';
  }

  @override
  String transferOfferSnippets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count स्निपेट',
      one: '1 स्निपेट',
      zero: 'कुनै स्निपेट छैन',
    );
    return '$_temp0';
  }

  @override
  String get menuSettings => 'सेटिङ';

  @override
  String get menuTrustedHostKeys => 'विश्वसनीय होस्ट कुञ्जीहरू';

  @override
  String get menuDiagnostics => 'निदान';

  @override
  String get transferFirewallNote =>
      'macOS ले SSHetu लाई आउने जडानहरू स्वीकार गर्न दिने कि नदिने भनी सोध्न सक्छ। अनुमति दिनुहोस् — अर्को डिभाइस यो डिभाइसमा जडान हुन्छ, त्यसैले अनुमतिबिना केही पनि तपाईंसम्म पुग्न सक्दैन।';

  @override
  String get transferFirewallNoteWindows =>
      'Windows ले SSHetu लाई यो नेटवर्कमा सञ्चार गर्न दिने कि नदिने भनी सोध्न सक्छ। आफ्नो निजी नेटवर्कमा अनुमति दिनुहोस् — अर्को डिभाइस यो डिभाइसमा जडान हुन्छ, त्यसैले अनुमतिबिना केही पनि तपाईंसम्म पुग्न सक्दैन।';

  @override
  String get transferStepPermission =>
      'जडानहरू स्वीकार गर्न macOS सँग अनुमति माग्दै…';

  @override
  String get transferStepBinding => 'पोर्ट खोल्दै…';

  @override
  String get transferCancel => 'रद्द गर्नुहोस्';

  @override
  String get transferNotStarted => 'सेयरिङ सुरु भएको छैन।';

  @override
  String get menuCloseTab => 'ट्याब बन्द गर्नुहोस्';

  @override
  String get menuWindow => 'विन्डो';

  @override
  String get menuMinimize => 'सानो बनाउनुहोस्';

  @override
  String get menuZoom => 'जुम';

  @override
  String get menuFullScreen => 'पूर्ण स्क्रिनमा जानुहोस्';

  @override
  String get menuBringAllToFront => 'सबैलाई अगाडि ल्याउनुहोस्';

  @override
  String get menuHide => 'SSHetu लुकाउनुहोस्';

  @override
  String get menuHideOthers => 'अरूलाई लुकाउनुहोस्';

  @override
  String get menuShowAll => 'सबै देखाउनुहोस्';

  @override
  String get menuServices => 'सेवाहरू';

  @override
  String get menuQuit => 'SSHetu बन्द गर्नुहोस्';

  @override
  String get menuAboutApp => 'SSHetu को बारेमा';

  @override
  String get backupTitle => 'ब्याकअप';

  @override
  String get backupBody =>
      'तपाईंका सर्भर, कुञ्जी र टनेलहरूको इन्क्रिप्ट गरिएको प्रति, तपाईंले राख्ने फाइलका रूपमा सेभ हुन्छ।';

  @override
  String get backupExport => 'ब्याकअप सेभ गर्नुहोस्…';

  @override
  String get backupImport => 'ब्याकअपबाट पुनर्स्थापना गर्नुहोस्…';

  @override
  String get backupPassphrase => 'पासफ्रेज';

  @override
  String get backupPassphraseConfirm => 'पासफ्रेज दोहोर्‍याउनुहोस्';

  @override
  String get backupPassphraseHelp =>
      'यो पासफ्रेज नै फाइललाई सुरक्षित राख्ने एक मात्र कुरा हो। यसलाई फेरि प्राप्त गर्न सकिँदैन — यो हरायो भने, ब्याकअप पनि गयो।';

  @override
  String get backupPassphraseMismatch => 'दुई पासफ्रेज फरक छन्।';

  @override
  String backupPassphraseTooShort(int count) {
    return 'कम्तीमा $count अक्षर प्रयोग गर्नुहोस्।';
  }

  @override
  String get backupStrengthWeak => 'कमजोर — अनुमान गर्न सजिलो';

  @override
  String get backupStrengthFair => 'ठिकै';

  @override
  String get backupStrengthStrong => 'बलियो';

  @override
  String get backupIncludeSecrets => 'कुञ्जी र पासवर्डहरू समावेश गर्नुहोस्';

  @override
  String get backupIncludeSecretsBody =>
      'यिनबिना ब्याकअपले तपाईंका सर्भरहरू पुनर्स्थापना गर्छ, तर कुञ्जीहरू फेरि दिनुपर्नेछ।';

  @override
  String get backupWorking => 'इन्क्रिप्ट गर्दै…';

  @override
  String backupSaved(String path) {
    return 'ब्याकअप $path मा सेभ भयो';
  }

  @override
  String get backupShared => 'ब्याकअप सेभ गर्न तयार छ।';

  @override
  String get backupSaveAnother => 'अर्को सेभ गर्नुहोस्';

  @override
  String get backupRestoreTitle => 'ब्याकअप पुनर्स्थापना गर्नुहोस्';

  @override
  String get backupRestoreBody =>
      'ब्याकअप फाइल छान्नुहोस्, अनि त्यो सेभ गर्दा प्रयोग गरिएको पासफ्रेज हाल्नुहोस्।';

  @override
  String get backupChooseFile => 'फाइल छान्नुहोस्…';

  @override
  String get backupOpening => 'खोल्दै…';

  @override
  String get backupOpen => 'ब्याकअप खोल्नुहोस्';

  @override
  String get backupRestore => 'पुनर्स्थापना गर्नुहोस्';

  @override
  String get backupRestoreWarning =>
      'पुनर्स्थापनाले यो डिभाइसमा भएका उही नामका कुराहरू बदल्छ। यसलाई पूर्ववत् गर्न सकिँदैन।';

  @override
  String backupContents(
    int hosts,
    int identities,
    int tunnels,
    int knownHosts,
  ) {
    return '$hosts सर्भर, $identities कुञ्जी, $tunnels टनेल, $knownHosts विश्वसनीय होस्ट कुञ्जी';
  }

  @override
  String get backupWithSecrets =>
      'निजी कुञ्जी र सेभ गरिएका पासवर्डहरू समावेश छन्।';

  @override
  String get backupWithoutSecrets => 'निजी कुञ्जी वा पासवर्डहरू समावेश छैनन्।';

  @override
  String backupWrittenOn(String date, String version) {
    return '$date मा SSHetu $version ले सेभ गरेको';
  }

  @override
  String get backupRestored => 'पुनर्स्थापना भयो।';

  @override
  String get menuSaveBackup => 'ब्याकअप सेभ गर्नुहोस्…';

  @override
  String get menuRestoreBackup => 'ब्याकअपबाट पुनर्स्थापना गर्नुहोस्…';

  @override
  String get keySetupTitle => 'पासवर्डको सट्टा कुञ्जी प्रयोग गर्नुहोस्';

  @override
  String get keySetupBody =>
      'यो सर्भरको authorized_keys मा सार्वजनिक कुञ्जी थप्छ, त्यसले साँच्चै लगइन गराउँछ कि जाँच्छ, अनि यहाँ तपाईंको पासवर्ड सेभ गर्न छोड्छ।';

  @override
  String get keySetupChooseKey => 'कुन कुञ्जी?';

  @override
  String get keySetupGenerate => 'नयाँ कुञ्जी बनाउनुहोस्';

  @override
  String get keySetupStart => 'सेटअप गर्नुहोस्';

  @override
  String get keySetupInstalling => 'सर्भरमा कुञ्जी थप्दै…';

  @override
  String get keySetupVerifying => 'कुञ्जीद्वारा लगइन गर्दै…';

  @override
  String get keySetupFinishing => 'मिलाउँदै…';

  @override
  String get keySetupRollingBack => 'सर्भरलाई पहिलेकै अवस्थामा फर्काउँदै…';

  @override
  String keySetupDone(String host, String key) {
    return 'सम्पन्न — $host ले अब $key प्रयोग गर्छ, र सेभ गरिएको पासवर्ड हटाइएको छ।';
  }

  @override
  String get keySetupAlreadyPresent => 'त्यो कुञ्जी सर्भरमा पहिल्यै थियो।';

  @override
  String get keySetupServerNote =>
      'यसले सर्भरको आफ्नै सेटिङ बदल्दैन। सर्भरले अझै अरू क्लाइन्टबाट पासवर्ड स्वीकार गर्छ — यो एपले मात्र पासवर्ड प्रयोग गर्न छोड्छ।';

  @override
  String get keySetupNoKeys =>
      'तपाईंसँग अहिलेसम्म कुनै कुञ्जी छैन। अगाडि बढ्न एउटा बनाउनुहोस्।';

  @override
  String get menuUseKeyInstead => 'पासवर्डको सट्टा कुञ्जी प्रयोग गर्नुहोस्…';

  @override
  String get keySetupUnavailable =>
      'पहिले यो सर्भरमा जडान गर्नुहोस् — कुञ्जी तपाईंसँग पहिल्यै भएको सेसन मार्फत स्थापना हुन्छ।';

  @override
  String get secretNotErased =>
      'SSHetu बाट हटाइयो, तर प्रणालीको किचेनले सेभ गरिएको गोप्य कुरा मेटाएन।';

  @override
  String get diagnosticsCopyOne => 'यो त्रुटि कपी गर्नुहोस्';

  @override
  String get diagnosticsRemoveOne => 'यो त्रुटि हटाउनुहोस्';

  @override
  String get diagnosticsCopied => 'कपी भयो।';

  @override
  String get diagnosticsRemoved => 'हटाइयो।';

  @override
  String get settingsDefaultKey => 'पूर्वनिर्धारित कुञ्जी';

  @override
  String get settingsDefaultKeyBody =>
      'नयाँ सर्भरहरू यही कुञ्जीबाट सुरु हुन्छन्। तपाईं यसलाई हरेक सर्भरमा बदल्न सक्नुहुन्छ।';

  @override
  String get settingsDefaultKeyNone => 'पूर्वनिर्धारित छैन';

  @override
  String get hostEditorConnection => 'सर्भर';

  @override
  String get hostEditorConnectionHint => 'root@192.168.1.10';

  @override
  String get hostEditorConnectionHelp =>
      'ठेगाना वा पूरै ssh कमान्ड पेस्ट गर्नुहोस् — त्यसबाट प्रयोगकर्ता, होस्ट र पोर्ट पढिन्छ।';

  @override
  String get hostEditorConnectionInvalid =>
      'त्यो SSHetu ले पुग्न सक्ने ठेगानाजस्तो देखिँदैन।';

  @override
  String get hostEditorIdentityFileIgnored =>
      '-i पाथलाई बेवास्ता गरियो। SSHetu ले आफूसँग भएका कुञ्जीहरू प्रयोग गर्छ; उन्नत विकल्पहरूमा एउटा छान्नुहोस्।';

  @override
  String get hostsNewGroup => 'नयाँ समूह';

  @override
  String get hostsShowNotes => 'नोटहरू';

  @override
  String get hostsTagFilterClear => 'ट्याग फिल्टर हटाउनुहोस्';

  @override
  String get hostGroupName => 'समूहको नाम';

  @override
  String get hostGroupCreate => 'बनाउनुहोस्';

  @override
  String get hostGroupRename => 'समूहको नाम बदल्नुहोस्';

  @override
  String get hostGroupRenameAction => 'नाम बदल्नुहोस्';

  @override
  String get hostGroupDelete => 'समूह मेटाउनुहोस्';

  @override
  String hostGroupDeleteConfirm(String name) {
    return '\"$name\" मेटाउने?';
  }

  @override
  String get hostGroupDeleteBody =>
      'समूह हटाइन्छ। यसका होस्टहरू राखिन्छन् र “समूहबाहिर” मा सर्छन्।';

  @override
  String get hostGroupUngrouped => 'समूहबाहिर';

  @override
  String get hostGroupEmpty =>
      'यो समूहमा अहिलेसम्म कुनै होस्ट छैन। होस्टको सम्पादकमा यसलाई छान्नुहोस्।';

  @override
  String hostGroupCollapse(String name) {
    return '$name खुम्च्याउनुहोस्';
  }

  @override
  String hostGroupExpand(String name) {
    return '$name फैलाउनुहोस्';
  }

  @override
  String get hostEditorOrganise => 'व्यवस्थित गर्नुहोस्';

  @override
  String get hostEditorGroup => 'समूह';

  @override
  String get hostEditorGroupNone => 'कुनै समूह छैन';

  @override
  String get hostEditorGroupNew => 'नयाँ समूह…';

  @override
  String get hostEditorTags => 'ट्यागहरू';

  @override
  String get hostEditorTagsHint =>
      'ट्याग टाइप गर्नुहोस्, अनि Enter वा अल्पविराम';

  @override
  String get hostEditorTagAdd => 'ट्याग थप्नुहोस्';

  @override
  String get hostEditorNotes => 'नोटहरू';

  @override
  String get hostEditorNotesHint => 'यो सर्भरबारे सम्झनलायक जेसुकै कुरा';

  @override
  String get hostEditorKeepalive => 'किपअलाइभ अन्तराल';

  @override
  String get hostEditorKeepaliveSuffix => 'सेकेन्ड';

  @override
  String get hostEditorKeepaliveHelp =>
      '0 ले किपअलाइभ बन्द गर्छ। छोटो अन्तरालले निष्क्रिय मोबाइल जडानहरूलाई टुट्नबाट जोगाउँछ।';

  @override
  String get hostEditorKeepaliveInvalid => '0–3600';

  @override
  String get hostEditorFontSize => 'टर्मिनल फन्ट आकार';

  @override
  String hostEditorFontSizeDefault(String size) {
    return 'एपको पूर्वनिर्धारित प्रयोग गर्नुहोस् ($size)';
  }

  @override
  String get hostEditorFontSizeHelp =>
      'टर्मिनलमा जुम गर्दा यो होस्टको होइन, एपको पूर्वनिर्धारित बदलिन्छ।';

  @override
  String get terminalFind => 'खोज्नुहोस्';

  @override
  String get menuFind => 'खोज्नुहोस्…';

  @override
  String get terminalFindHint => 'स्क्रोलब्याकमा खोज्नुहोस्';

  @override
  String terminalFindCount(int current, int total) {
    return '$total मध्ये $current';
  }

  @override
  String terminalFindCountCapped(int current, int total) {
    return '$total+ मध्ये $current';
  }

  @override
  String get terminalFindNoMatches => 'कुनै मेल छैन';

  @override
  String get terminalFindInvalidPattern => 'अमान्य ढाँचा';

  @override
  String get terminalFindCaseSensitive => 'ठूलो/सानो अक्षर मिलाउनुहोस्';

  @override
  String get terminalFindRegex => 'रेगुलर एक्स्प्रेसन';

  @override
  String get terminalFindOlder => 'पुरानो मेल (Enter)';

  @override
  String get terminalFindNewer => 'नयाँ मेल (Shift+Enter)';

  @override
  String get terminalFindClose => 'बन्द गर्नुहोस् (Esc)';

  @override
  String get terminalOpenLink => 'लिङ्क खोल्नुहोस्';

  @override
  String get terminalCopyLink => 'लिङ्क कपी गर्नुहोस्';

  @override
  String get terminalLinkSheetTitle => 'यो लिङ्क खोल्ने?';

  @override
  String get terminalLinkRefused =>
      'SSHetu ले http, https र mailto लिङ्क मात्र खोल्छ।';

  @override
  String get terminalLinkOpenFailed => 'लिङ्क खोल्न सकिएन।';

  @override
  String get terminalLinkCopied => 'लिङ्क कपी भयो';

  @override
  String get pasteConfirmTitle => 'पेस्ट गरेर चलाउने?';

  @override
  String pasteConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'कमान्डहरू चल्नेछन्',
      one: 'एउटा कमान्ड चल्नेछ',
    );
    return 'यो टेक्स्टमा लाइन ब्रेक छ, त्यसैले पेस्ट गर्दा शेल प्रम्प्टमा $_temp0।';
  }

  @override
  String pasteConfirmLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लाइन',
      one: '1 लाइन',
    );
    return '$_temp0';
  }

  @override
  String pasteConfirmMoreLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '…र थप $count लाइन',
      one: '…र थप 1 लाइन',
    );
    return '$_temp0';
  }

  @override
  String pasteHiddenRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लुकेका अक्षर हटाइए',
      one: '1 लुकेको अक्षर हटाइयो',
    );
    return '$_temp0';
  }

  @override
  String get pasteDontAskAgain => 'फेरि नसोध्नुहोस्';

  @override
  String get pasteConfirmAction => 'पेस्ट गर्नुहोस्';

  @override
  String get settingsTerminal => 'टर्मिनल';

  @override
  String get settingsConfirmPaste => 'धेरै लाइनको पेस्ट पुष्टि गर्नुहोस्';

  @override
  String get settingsConfirmPasteBody =>
      'लाइन ब्रेक भएको टेक्स्ट पेस्ट गर्नुअघि सोध्नुहोस्, किनभने त्यसले कमान्डहरू चलाउँछ।';

  @override
  String get settingsKeepAlive => 'पृष्ठभूमिमा जडानहरू जीवित राख्नुहोस्';

  @override
  String get settingsKeepAliveBody =>
      'सेसन वा टनेल खुला हुँदा सूचना देखाउँछ, ताकि एप बदल्दा Android ले तिनलाई बन्द नगरोस्।';

  @override
  String get keepAliveChannelName => 'सक्रिय जडानहरू';

  @override
  String get keepAliveTitle => 'जडानहरू खुला छन्';

  @override
  String keepAliveSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेसन',
      one: '1 सेसन',
    );
    return '$_temp0';
  }

  @override
  String keepAliveTunnels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count टनेल',
      one: '1 टनेल',
    );
    return '$_temp0';
  }

  @override
  String keepAliveSummaryBoth(String sessions, String tunnels) {
    return '$sessions, $tunnels सक्रिय';
  }

  @override
  String keepAliveSummaryOne(String what) {
    return '$what सक्रिय';
  }

  @override
  String get keepAliveDisconnectAll => 'सबै जडान विच्छेद गर्नुहोस्';

  @override
  String get settingsKeepSessions => 'सर्भरमा सेसनहरू चलिरहन दिनुहोस्';

  @override
  String get settingsKeepSessionsBody =>
      'सर्भरमा tmux भएमा हरेक ट्याबलाई त्यसभित्र चलाउँछ, ताकि जडान टुटे पनि जहाँ छोडिएको थियो त्यहीँबाट सुरु हुन्छ। ट्याब बन्द गर्दा सेसन समाप्त हुन्छ।';

  @override
  String get terminalNoticeConnectionLost => '[जडान टुट्यो — पुनः जडान हुँदै]';

  @override
  String get terminalNoticeSessionEnded => '[सेसन समाप्त भयो]';

  @override
  String get terminalNoticeSessionClosed => '[सेसन बन्द भयो]';

  @override
  String get terminalNoticeReconnected => '[पुनः जडान भयो]';

  @override
  String get terminalNoticeTmuxUnavailable =>
      '[यो सर्भरमा tmux स्थापना गरिएको छैन, त्यसैले जडान टुटेमा यो सेसन बाँच्दैन]';

  @override
  String terminalReconnectWaiting(int seconds, int attempt) {
    return 'जडान टुट्यो — $seconds s मा पुनः जडान हुँदै (प्रयास $attempt)';
  }

  @override
  String terminalReconnectWaitingShort(int seconds) {
    return '$seconds s मा पुनः जडान हुँदै';
  }

  @override
  String get terminalReconnecting => 'पुनः जडान हुँदै…';

  @override
  String get terminalRetryNow => 'अहिल्यै प्रयास गर्नुहोस्';

  @override
  String get terminalStopReconnecting => 'रोक्नुहोस्';

  @override
  String get settingsTerminalAppearance => 'टर्मिनलको रूप';

  @override
  String get settingsTerminalTheme => 'टर्मिनल थिम';

  @override
  String get terminalThemeAdaptive => 'उज्यालो र अँध्यारो अनुसार';

  @override
  String get terminalThemeFixedDark => 'अँध्यारो';

  @override
  String get terminalThemeFixedLight => 'उज्यालो';

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
  String get settingsTerminalFont => 'टर्मिनल फन्ट';

  @override
  String get terminalFontSystem => 'प्रणालीको मोनोस्पेस';

  @override
  String get settingsCursorShape => 'कर्सर';

  @override
  String get cursorShapeBlock => 'ब्लक';

  @override
  String get cursorShapeUnderline => 'अन्डरलाइन';

  @override
  String get cursorShapeBar => 'बार';

  @override
  String get settingsCursorBlink => 'झिम्किने कर्सर';

  @override
  String get settingsCursorBlinkBody =>
      'vim जस्ता प्रोग्रामहरूले चलिरहँदा कर्सर अझै बदल्न सक्छन्।';

  @override
  String get settingsScrollback => 'स्क्रोलब्याक';

  @override
  String settingsScrollbackValue(String lines) {
    return '$lines लाइन · नयाँ ट्याबहरूमा लागू हुन्छ';
  }

  @override
  String scrollbackLinesOption(String lines) {
    return '$lines लाइन';
  }

  @override
  String get hostEditorTerminalTheme => 'टर्मिनल थिम';

  @override
  String hostEditorTerminalThemeDefault(String name) {
    return 'पूर्वनिर्धारित प्रयोग गर्नुहोस् ($name)';
  }

  @override
  String get terminalNoticeTmuxSessionGone =>
      '[सर्भरमा राखिएको सेसन समाप्त भइसकेको छ, त्यसैले यो नयाँ शेल हो]';

  @override
  String get hostsRunningSessions => 'चलिरहेका सेसनहरू…';

  @override
  String get sessionRunningSessions => 'यो सर्भरका सेसनहरू…';

  @override
  String get serverInfoTitle => 'सर्भर जानकारी';

  @override
  String get serverInfoShow => 'सर्भर जानकारी';

  @override
  String get serverInfoHide => 'सर्भर जानकारी लुकाउनुहोस्';

  @override
  String get serverInfoClose => 'सर्भर जानकारी बन्द गर्नुहोस्';

  @override
  String get serverInfoOverview => 'सारांश';

  @override
  String get serverInfoProcesses => 'प्रोसेसहरू';

  @override
  String get serverInfoHostname => 'होस्टनाम';

  @override
  String get serverInfoSystem => 'प्रणाली';

  @override
  String get serverInfoKernel => 'कर्नेल';

  @override
  String get serverInfoUptime => 'अपटाइम';

  @override
  String get serverInfoLoad => 'लोड';

  @override
  String get serverInfoCpu => 'CPU';

  @override
  String serverInfoCpuCores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कोर',
      one: '1 कोर',
    );
    return '$_temp0';
  }

  @override
  String serverInfoCpuHistory(int count) {
    return 'पछिल्ला $count रिडिङमा CPU प्रयोग';
  }

  @override
  String get serverInfoMemory => 'मेमोरी';

  @override
  String get serverInfoSwap => 'स्वाप';

  @override
  String get serverInfoNoSwap => 'स्वाप छैन';

  @override
  String serverInfoUsedOfTotal(String used, String total) {
    return '$total मध्ये $used';
  }

  @override
  String get serverInfoFilesystems => 'फाइल सिस्टम';

  @override
  String get serverInfoNetwork => 'नेटवर्क';

  @override
  String get serverInfoNetDown => 'डाउन';

  @override
  String get serverInfoNetUp => 'अप';

  @override
  String serverInfoProcessCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रोसेस',
      one: '1 प्रोसेस',
    );
    return '$_temp0';
  }

  @override
  String get serverInfoLimited => 'यो प्रणालीमा सीमित जानकारी';

  @override
  String get serverInfoLimitedBody =>
      'यो सर्भरले CPU, मेमोरी वा लोड SSHetu ले पढ्न सक्ने तरिकाले दिँदैन, त्यसैले आधारभूत कुरा मात्र देखाइन्छ।';

  @override
  String get serverInfoOffline => 'जडान छैन';

  @override
  String get serverInfoOfflineBody =>
      'सेसन पुनः जडान भएपछि तथ्याङ्क फेरि आउँछन्।';

  @override
  String serverInfoError(String error) {
    return 'यो सर्भरको तथ्याङ्क पढ्न सकिएन: $error';
  }

  @override
  String get serverInfoNoSession => 'कुनै सेसन छानिएको छैन';

  @override
  String get serverInfoNoSessionBody =>
      'पछाडिको सर्भरको विवरण हेर्न टर्मिनल खोल्नुहोस्।';

  @override
  String get serverInfoWaiting => 'मापन गर्दै…';

  @override
  String get processesFilter => 'नाम, प्रयोगकर्ता वा PID ले फिल्टर गर्नुहोस्';

  @override
  String get processesSortBy => 'क्रमबद्ध गर्ने आधार';

  @override
  String get processesSortCpu => 'CPU';

  @override
  String get processesSortMem => 'मेमोरी';

  @override
  String get processesSortPid => 'PID';

  @override
  String get processesRefresh => 'रिफ्रेस गर्नुहोस्';

  @override
  String get processesEmpty => 'कुनै प्रोसेस मेल खाँदैन';

  @override
  String get processesNoUsage =>
      'यो सर्भरको ps ले CPU वा मेमोरी प्रयोग देखाउँदैन।';

  @override
  String get processesKill => 'रोक्नुहोस् (SIGTERM)';

  @override
  String get processesForceKill => 'जबरजस्ती रोक्नुहोस् (SIGKILL)';

  @override
  String processesActions(String name) {
    return '$name का कार्यहरू';
  }

  @override
  String processesKillTitle(String name) {
    return '$name रोक्ने?';
  }

  @override
  String processesKillBody(String name, int pid) {
    return '$name (PID $pid) लाई SIGTERM पठाउँछ। यसलाई बन्द हुन भनिन्छ, र यसले पहिले आफ्नो काम समेट्न सक्छ।';
  }

  @override
  String processesForceKillTitle(String name) {
    return '$name जबरजस्ती रोक्ने?';
  }

  @override
  String processesForceKillBody(String name, int pid) {
    return '$name (PID $pid) लाई SIGKILL पठाउँछ। यो केही पनि सेभ गर्ने मौका नपाई तुरुन्तै रोकिन्छ।';
  }

  @override
  String get processesKillConfirm => 'रोक्नुहोस्';

  @override
  String get processesForceKillConfirm => 'जबरजस्ती रोक्नुहोस्';

  @override
  String processesSignalSent(String signal, String name, int pid) {
    return '$name (PID $pid) लाई $signal पठाइयो';
  }

  @override
  String processesSignalFailed(String name, int pid, String error) {
    return '$name (PID $pid) लाई सिग्नल पठाउन सकिएन: $error';
  }

  @override
  String processesLoadFailed(String error) {
    return 'प्रोसेसहरू सूचीबद्ध गर्न सकिएन: $error';
  }

  @override
  String osFamilyName(String family) {
    String _temp0 = intl.Intl.selectLogic(family, {
      'ubuntu': 'Ubuntu',
      'debian': 'Debian',
      'fedora': 'Fedora',
      'rhel': 'Red Hat परिवार',
      'arch': 'Arch Linux',
      'alpine': 'Alpine Linux',
      'opensuse': 'openSUSE',
      'freebsd': 'FreeBSD',
      'macos': 'macOS',
      'windows': 'Windows',
      'linux': 'Linux',
      'other': 'अज्ञात प्रणाली',
    });
    return '$_temp0';
  }

  @override
  String runningSessionsTitle(String host) {
    return '$host का सेसनहरू';
  }

  @override
  String get runningSessionsIntro =>
      'SSHetu ले यो सर्भरमा चलाइराखेका शेलहरू — यो डिभाइस र तपाईंका अन्य डिभाइसबाट। जहाँ छोड्नुभएको थियो त्यहीँबाट सुरु गर्न एउटामा जोडिनुहोस्: डेस्कटपमा केही सुरु गर्नुहोस्, फोनबाट जारी राख्नुहोस्।';

  @override
  String get runningSessionsSharedNote =>
      'अर्को डिभाइसमा खुला सेसनमा जोडिँदा त्यो साझा हुन्छ: दुवै स्क्रिनले उही शेल देखाउँछन्, र जुनसुकैले टाइप गर्न सक्छ। यहाँबाट जोडिएको ट्याब बन्द गर्दा सेसन चलिरहन्छ — काम सकेपछि यहाँबाट समाप्त गर्नुहोस्।';

  @override
  String get runningSessionsRefresh => 'रिफ्रेस गर्नुहोस्';

  @override
  String get runningSessionsError => 'यो सर्भरका सेसनहरू सूचीबद्ध गर्न सकिएन';

  @override
  String get runningSessionsNoTmux =>
      'यो सर्भरमा tmux स्थापना गरिएको छैन, त्यसैले SSHetu ले यसमा सेसनहरू चलिरहन दिन सक्दैन।';

  @override
  String get runningSessionsEmpty => 'यो सर्भरमा कुनै SSHetu सेसन चलिरहेको छैन';

  @override
  String get runningSessionsEmptyBody =>
      '“सर्भरमा सेसनहरू चलिरहन दिनुहोस्” खोलेर खोलिएका ट्याबहरू, तपाईंका कुनै पनि डिभाइसबाट, चलिरहेसम्म यहाँ देखिन्छन्।';

  @override
  String get runningSessionsThisDevice => 'यो डिभाइस';

  @override
  String runningSessionsOtherDevice(String id) {
    return 'अर्को डिभाइस ($id)';
  }

  @override
  String get runningSessionsOlder => 'SSHetu को पुरानो संस्करण';

  @override
  String runningSessionsStarted(String age) {
    return '$age अघि सुरु भएको';
  }

  @override
  String runningSessionsActive(String age) {
    return '$age अघि सक्रिय';
  }

  @override
  String runningSessionsRunning(String command) {
    return '$command चलिरहेको';
  }

  @override
  String get runningSessionsAttached => 'अन्यत्र जोडिएको';

  @override
  String get runningSessionsOpenHere => 'यहाँ खोल्नुहोस्';

  @override
  String get runningSessionsAttach => 'जोडिनुहोस्';

  @override
  String get runningSessionsShow => 'देखाउनुहोस्';

  @override
  String get runningSessionsEnd => 'समाप्त गर्नुहोस्';

  @override
  String get runningSessionsEndTitle => 'यो सेसन समाप्त गर्ने?';

  @override
  String runningSessionsEndBody(String host) {
    return '$host मा यसभित्र चलिरहेका सबै कुरा, यसमा जोडिएका हरेक डिभाइसमा, रोकिन्छन्। यसलाई पूर्ववत् गर्न सकिँदैन।';
  }

  @override
  String runningSessionsEndFailed(String error) {
    return 'सेसन समाप्त गर्न सकिएन: $error';
  }

  @override
  String runningSessionsAttachFailed(String error) {
    return 'जोडिन सकिएन: $error';
  }

  @override
  String get settingsReopenTabs => 'सुरु हुँदा ट्याबहरू फेरि खोल्नुहोस्';

  @override
  String get settingsReopenTabsBody =>
      'SSHetu पछिल्लो पटक बन्द हुँदा खुला रहेका टर्मिनल ट्याबहरू फर्काउँछ, र सर्भरमा राखिएका सेसनहरूमा फेरि जोडिन्छ।';

  @override
  String get settingsReopenTabsAsk => 'सोध्नुहोस्';

  @override
  String get settingsReopenTabsAlways => 'सधैँ';

  @override
  String get settingsReopenTabsNever => 'नखोल्ने';

  @override
  String get restoreTabsTitle => 'तपाईंका ट्याबहरू फेरि खोल्ने?';

  @override
  String restoreTabsBody(int count, String hosts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'SSHetu पछिल्लो पटक बन्द हुँदा $count टर्मिनल ट्याब खुला थिए: $hosts।',
      one: 'SSHetu पछिल्लो पटक बन्द हुँदा 1 टर्मिनल ट्याब खुला थियो: $hosts।',
    );
    return '$_temp0';
  }

  @override
  String get restoreTabsRemember => 'फेरि नसोध्नुहोस्';

  @override
  String get restoreTabsNotNow => 'अहिले होइन';

  @override
  String get restoreTabsReopen => 'फेरि खोल्नुहोस्';

  @override
  String get hostEditorEnv => 'वातावरण';

  @override
  String get hostEditorEnvHelp =>
      'यो होस्टको हरेक नयाँ शेलमा ठ्याक्कै टाइप गरिएजस्तै सेट हुन्छ। सर्भरमा पहिल्यै राखिएको सेसनले सुरु हुँदाकै मानहरू राख्छ।';

  @override
  String get hostEditorEnvName => 'नाम';

  @override
  String get hostEditorEnvValue => 'मान';

  @override
  String get hostEditorEnvAdd => 'भेरिएबल थप्नुहोस्';

  @override
  String get hostEditorEnvRemove => 'भेरिएबल हटाउनुहोस्';

  @override
  String get hostEditorEnvMissingName => 'यसको नाम दिनुहोस्';

  @override
  String get hostEditorEnvInvalidName =>
      'अक्षर, अङ्क र _ मात्र, अङ्कबाट सुरु नहुने';

  @override
  String get hostEditorEnvDuplicateName => 'माथि पहिल्यै सेट गरिएको';

  @override
  String get hostEditorEnvInvalidValue => 'लाइन ब्रेक राख्न मिल्दैन';

  @override
  String get hostEditorForwardAgent => 'SSH एजेन्ट फर्वार्ड गर्नुहोस्';

  @override
  String get hostEditorForwardAgentHelp =>
      'तपाईं जडित रहँदासम्म यो सर्भरलाई अन्यत्र साइन इन गर्न तपाईंका कुञ्जीहरू प्रयोग गर्न दिन्छ। तपाईंले विश्वास गरेका सर्भरहरूमा मात्र यो सक्रिय गर्नुहोस्। सर्भरमा AllowAgentForwarding बन्द छ भने, जडान असफल हुनेछ।';

  @override
  String get exportJsonTitle => 'JSON का रूपमा निर्यात (गोप्य कुराबिना)';

  @override
  String get exportJsonSubtitle =>
      'अन्य उपकरणहरूका लागि तपाईंका होस्ट, टनेल र स्निपेटहरूको पढ्न मिल्ने फाइल। कुञ्जी र पासवर्डहरू हटाइन्छन्।';

  @override
  String get exportJsonBody =>
      'होस्ट, समूह, टनेल, स्निपेट, सार्वजनिक कुञ्जी र विश्वसनीय होस्ट कुञ्जीहरू, जुनसुकै उपकरणले पढ्न सक्ने दस्तावेजीकृत ढाँचामा। यसलाई फेरि SSHetu मा आयात गर्दा केही गुम्दैन।';

  @override
  String get exportJsonNoSecrets =>
      'निजी कुञ्जी, कुञ्जीका पासफ्रेज र सेभ गरिएका पासवर्डहरू कहिल्यै समावेश हुँदैनन्। ती पनि राख्न, बरु इन्क्रिप्ट गरिएको ब्याकअप सेभ गर्नुहोस्।';

  @override
  String get exportJsonBackupInstead => 'इन्क्रिप्ट गरिएको ब्याकअप…';

  @override
  String get exportJsonAction => 'निर्यात गर्नुहोस्';

  @override
  String exportJsonSaved(String path) {
    return '$path मा निर्यात भयो';
  }

  @override
  String get exportJsonShared => 'निर्यात सेभ गर्न तयार छ।';

  @override
  String exportJsonFailed(String error) {
    return 'निर्यात गर्न सकिएन: $error';
  }

  @override
  String get importJsonTitle => 'JSON बाट आयात';

  @override
  String get importJsonSubtitle =>
      'SSHetu को JSON निर्यात। केही लेखिनुअघि के बदलिन्छ भनी तपाईंले हेर्न पाउनुहुन्छ।';

  @override
  String get importJsonNotJson => 'यो फाइल JSON होइन।';

  @override
  String get importJsonNotExport =>
      'यो SSHetu निर्यात होइन। “JSON का रूपमा निर्यात” ले सेभ गरिएको फाइल छान्नुहोस्।';

  @override
  String importJsonNewer(int version, int supported) {
    return 'यो निर्यात SSHetu को नयाँ संस्करणले लेखेको हो (ढाँचा संस्करण $version; यो बिल्डले संस्करण $supported सम्म पढ्छ)। SSHetu अपडेट गरी फेरि प्रयास गर्नुहोस्।';
  }

  @override
  String get importJsonInvalidVersion =>
      'यो निर्यातमा मान्य ढाँचा संस्करण छैन, त्यसैले पढ्न सकिँदैन।';

  @override
  String importJsonMalformed(String field) {
    return 'यो निर्यात बिग्रेको छ वा गलत तरिकाले सम्पादन गरिएको छ: $field छैन वा अमान्य छ।';
  }

  @override
  String get importJsonReadFailed => 'त्यो फाइल पढ्न सकिएन।';

  @override
  String importJsonFrom(String name) {
    return '$name बाट';
  }

  @override
  String importJsonHostsNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नयाँ होस्ट',
      one: '1 नयाँ होस्ट',
    );
    return '$_temp0';
  }

  @override
  String importJsonHostsUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सेभ गरिएका $count होस्ट अपडेट भए (उही id)',
      one: 'सेभ गरिएको 1 होस्ट अपडेट भयो (उही id)',
    );
    return '$_temp0';
  }

  @override
  String importJsonHostsUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count होस्ट पहिल्यै अद्यावधिक',
      one: '1 होस्ट पहिल्यै अद्यावधिक',
    );
    return '$_temp0';
  }

  @override
  String importJsonConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count होस्ट ठेगानाका आधारमा सेभ गरिएका होस्टहरूसँग मेल खान्छन्',
      one: '1 होस्ट ठेगानाका आधारमा सेभ गरिएको होस्टसँग मेल खान्छ',
    );
    return '$_temp0';
  }

  @override
  String get importJsonConflictsBody =>
      'सेभ गरिएको होस्टकै प्रयोगकर्ता, होस्ट र पोर्ट, तर फरक id — सम्भवतः दुई डिभाइसमा सेभ गरिएको उही सर्भर।';

  @override
  String get importJsonMerge => 'मर्ज गर्नुहोस्';

  @override
  String get importJsonAddAsNew => 'नयाँका रूपमा थप्नुहोस्';

  @override
  String get importJsonMergeHelp =>
      'सेभ गरिएको होस्टले फाइलका सेटिङ लिन्छ। यसका टनेल र सेभ गरिएको पासवर्ड जोडिएकै रहन्छन्।';

  @override
  String get importJsonAddAsNewHelp =>
      'सेभ गरिएको होस्ट जस्ताको तस्तै रहन्छ, र फाइलको होस्ट दोस्रो होस्टका रूपमा थपिन्छ।';

  @override
  String importJsonConflictRow(String incoming, String existing) {
    return '$incoming → $existing का रूपमा सेभ गरिएको';
  }

  @override
  String get importJsonAlso => 'यो फाइलमा यी पनि छन्';

  @override
  String importJsonGroups(int added, int updated) {
    return 'समूह: $added नयाँ, $updated अपडेट';
  }

  @override
  String importJsonTunnels(int count) {
    return 'टनेल: $count थप्ने वा अपडेट गर्ने';
  }

  @override
  String importJsonSnippets(int added, int updated) {
    return 'स्निपेट: $added नयाँ, $updated अपडेट';
  }

  @override
  String importJsonKnownHosts(int count) {
    return 'विश्वसनीय होस्ट कुञ्जी: $count नयाँ';
  }

  @override
  String importJsonKnownHostsConflicting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'फाइलमा भएका $count विश्वसनीय होस्ट कुञ्जी यहाँ सेभ गरिएकाभन्दा फरक छन्, त्यसैले छोडिन्छन्। आयातले कहिल्यै विश्वासको निर्णय बदल्दैन।',
      one: 'फाइलमा भएको 1 विश्वसनीय होस्ट कुञ्जी यहाँ सेभ गरिएकोभन्दा फरक छ, त्यसैले छोडिन्छ। आयातले कहिल्यै विश्वासको निर्णय बदल्दैन।',
    );
    return '$_temp0';
  }

  @override
  String get importJsonMissingKeysTitle => 'ल्याउनुपर्ने कुञ्जीहरू';

  @override
  String get importJsonMissingKeysBody =>
      'निर्यातमा कहिल्यै निजी कुञ्जी हुँदैन। तपाईंले कुञ्जी यो डिभाइसमा ल्याएर — इन्क्रिप्ट गरिएको ब्याकअप, “डिभाइसमा पठाउनुहोस्”, वा कुञ्जी खण्डमा पेस्ट गरेर — होस्टमा नछानेसम्म यी होस्टहरू कुञ्जीबिना आयात हुन्छन्।';

  @override
  String importJsonMissingKeyHosts(String hosts) {
    return 'प्रयोग गर्ने: $hosts';
  }

  @override
  String get importJsonNothing => 'यो फाइलका सबै कुरा यो डिभाइसमा पहिल्यै छन्।';

  @override
  String get importJsonAction => 'आयात गर्नुहोस्';

  @override
  String importJsonDone(int hosts, int tunnels, int snippets) {
    return '$hosts होस्ट, $tunnels टनेल र $snippets स्निपेट आयात भए';
  }

  @override
  String get puttyImportTitle => 'PuTTY बाट आयात';

  @override
  String get puttyImportSubtitleWindows =>
      'यो PC को PuTTY मा सेभ गरिएका सेसनहरू, वा .reg फाइल';

  @override
  String get puttyImportSubtitleFile =>
      'Windows मा निर्यात गरिएको PuTTY सेसनहरूको .reg फाइलबाट';

  @override
  String get puttyImportFile => 'PuTTY .reg फाइल आयात गर्नुहोस्';

  @override
  String get puttyChooseFile => '.reg फाइल छान्नुहोस्…';

  @override
  String get puttyNoneFoundTitle => 'कुनै PuTTY सेसन भेटिएन';

  @override
  String get puttyNoneFoundBody =>
      'यो Windows खातामा PuTTY का कुनै सेभ गरिएका सेसन छैनन्। बरु .reg फाइल छान्न सक्नुहुन्छ: ती सेसन भएको PC मा regedit खोलेर HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions रजिस्ट्री कुञ्जी निर्यात गर्नुहोस्।';

  @override
  String get puttyNoneInFile => 'त्यो फाइलमा कुनै PuTTY सेसन छैन।';

  @override
  String puttyReadFailed(String error) {
    return 'PuTTY सेसनहरू पढ्न सकिएन: $error';
  }

  @override
  String puttySkippedProtocol(String protocol) {
    return 'SSH होइन ($protocol), त्यसैले छोडिन्छ';
  }

  @override
  String get puttySkippedNoHost => 'होस्ट नाम छैन, त्यसैले छोडिन्छ';

  @override
  String get puttyAlreadySaved => 'पहिल्यै सेभ गरिएको';

  @override
  String puttyNoUsername(String name) {
    return 'प्रयोगकर्ता नाम सेभ गरिएको छैन; $name प्रयोग हुनेछ';
  }

  @override
  String puttyPpk(String file) {
    return 'कुञ्जी आयात भएन: $file';
  }

  @override
  String puttyProxy(String proxy) {
    return 'प्रोक्सी आयात भएन: $proxy';
  }

  @override
  String puttyForwards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count फर्वार्ड टनेल बन्छन्, तपाईंले समीक्षा नगरेसम्म बन्द रहन्छन्',
      one: '1 फर्वार्ड टनेल बन्छ, तपाईंले समीक्षा नगरेसम्म बन्द रहन्छ',
    );
    return '$_temp0';
  }

  @override
  String puttyInvalidForwards(String list) {
    return 'बुझ्न नसकिएका फर्वार्डहरू: $list';
  }

  @override
  String get puttyPpkTitle => 'PuTTY कुञ्जीहरू (.ppk) सिधै प्रयोग गर्न सकिँदैन';

  @override
  String puttyPpkBody(String hosts) {
    return 'हरेक कुञ्जी PuTTYgen ले रूपान्तरण गर्नुहोस्: .ppk लोड गर्नुहोस्, अनि Conversions → Export OpenSSH key। नतिजालाई कुञ्जी खण्डमा आयात गरी होस्टमा छान्नुहोस्। .ppk कुञ्जी प्रयोग गर्ने होस्टहरू: $hosts';
  }

  @override
  String puttyImportAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count होस्ट आयात गर्नुहोस्',
      one: '1 होस्ट आयात गर्नुहोस्',
      zero: 'आयात गर्नुहोस्',
    );
    return '$_temp0';
  }

  @override
  String puttyImportDone(int hosts, int tunnels) {
    return '$hosts होस्ट र $tunnels टनेल आयात भए। तपाईंले समीक्षा गरी सुरु नगरेसम्म टनेलहरू बन्द रहन्छन्।';
  }

  @override
  String get importMoreSources => 'आयात गर्ने थप तरिकाहरू';

  @override
  String get hostEditorTmuxMode => 'यो सर्भरमा सेसनहरू चलिरहन दिनुहोस् (tmux)';

  @override
  String get hostEditorTmuxModeHelp =>
      'हरेक ट्याबलाई tmux भित्र चलाउँछ, ताकि जडान टुटे पनि जहाँ छोडिएको थियो त्यहीँबाट सुरु हुन्छ। पूर्वनिर्धारितले सेटिङ → टर्मिनलको सेटिङ पछ्याउँछ।';

  @override
  String get hostEditorTmuxModeDefaultOn => 'पूर्वनिर्धारित (अहिले चालू)';

  @override
  String get hostEditorTmuxModeDefaultOff => 'पूर्वनिर्धारित (अहिले बन्द)';

  @override
  String get hostEditorTmuxModeAlways => 'सधैँ';

  @override
  String get hostEditorTmuxModeNever => 'कहिल्यै होइन';

  @override
  String tmuxInstallPrompt(String host) {
    return '$host मा tmux स्थापना गरिएको छैन, त्यसैले जडान टुटेमा यो सेसन बाँच्दैन। स्थापना गर्ने?';
  }

  @override
  String get tmuxInstallCommandLabel => 'सर्भरमा यो कमान्ड चल्नेछ:';

  @override
  String get tmuxInstallCommandLabelTerminal =>
      'यो टर्मिनलमा यो कमान्ड चल्नेछ:';

  @override
  String get tmuxInstallPasswordNote =>
      'sudo ले टर्मिनलमै तपाईंको पासवर्ड माग्नेछ। SSHetu ले त्यो कहिल्यै देख्दैन।';

  @override
  String get tmuxInstallAction => 'स्थापना गर्नुहोस्';

  @override
  String get tmuxInstallActionTerminal => 'टर्मिनलमा चलाउनुहोस्';

  @override
  String get tmuxInstallNotNow => 'अहिले होइन';

  @override
  String get tmuxInstallNever => 'यो होस्टमा कहिल्यै होइन';

  @override
  String tmuxInstallRunning(String host) {
    return '$host मा tmux स्थापना हुँदैछ…';
  }

  @override
  String get tmuxInstallSucceeded =>
      'tmux स्थापना भयो। यो सेसन tmux मा फेरि सुरु गर्ने? यो ट्याबको शेल बन्द हुन्छ, र त्यसमा चलिरहेको सबै कुरा रोकिन्छ।';

  @override
  String get tmuxInstallRestart => 'tmux मा फेरि सुरु गर्नुहोस्';

  @override
  String get tmuxInstallLater => 'पछि';

  @override
  String get tmuxInstallFailed => 'tmux स्थापना गर्न सकिएन:';

  @override
  String get tmuxInstallFailedStaleLists =>
      'tmux स्थापना गर्न सकिएन: सर्भरको प्याकेज सूची पुरानो भइसकेको छ। सूची अद्यावधिक गरेर फेरि प्रयास गर्ने?';

  @override
  String get tmuxInstallUpdateAction => 'अद्यावधिक गरेर स्थापना गर्नुहोस्';

  @override
  String get tmuxInstallDismiss => 'हटाउनुहोस्';

  @override
  String get tmuxInstallTyped =>
      'टर्मिनलमा आफ्नो sudo पासवर्ड हाल्नुहोस्। स्थापना सकिएपछि यो सेसन tmux मा फेरि सुरु गर्नुहोस् — यो ट्याबको शेल बन्द हुन्छ, र त्यसमा चलिरहेको सबै कुरा रोकिन्छ।';

  @override
  String tmuxInstallUnknownManager(String host) {
    return '$host मा tmux स्थापना गरिएको छैन, र SSHetu ले यसको प्याकेज म्यानेजर चिन्दैन। सेसनहरू चलिरहन दिन सर्भरकै उपकरणहरूले tmux स्थापना गर्नुहोस्।';
  }

  @override
  String tmuxInstallNoPrivilege(String host) {
    return '$host मा tmux स्थापना गरिएको छैन। यसलाई स्थापना गर्न root चाहिन्छ, र यो खातामा sudo छैन। सर्भरको प्रशासकलाई tmux स्थापना गर्न भन्नुहोस्।';
  }

  @override
  String get terminalRestartInTmux => 'tmux मा फेरि सुरु गर्नुहोस्';

  @override
  String get terminalNoticeRestartedInTmux => '[tmux मा फेरि सुरु भयो]';

  @override
  String get tmuxRestartConfirmTitle => 'यो सेसन tmux मा फेरि सुरु गर्ने?';

  @override
  String get tmuxRestartConfirmBody =>
      'यो ट्याबको शेल बन्द हुन्छ, र त्यसमा चलिरहेको सबै कुरा रोकिन्छ। tmux भित्र नयाँ शेल खुल्छ, त्यसैले जडान टुटे पनि त्यो बाँच्छ।';

  @override
  String get tmuxRestartConfirmAction => 'फेरि सुरु गर्नुहोस्';

  @override
  String get settingsIntegrations => 'एकीकरण';

  @override
  String get mcpToggle => 'AI सहायकलाई SSHetu प्रयोग गर्न दिनुहोस्';

  @override
  String get mcpToggleBody =>
      'यो कम्प्युटरमा स्थानीय MCP सर्भर चलाउँछ। सहायकले तपाईंका होस्ट र खुला सेसन पढ्न सक्छ; केही परिवर्तन गर्ने हरेक कामका लागि पहिले तपाईंलाई सोधिन्छ। पासवर्ड र कुञ्जी कहिल्यै दिइँदैन।';

  @override
  String get mcpStatusStarting => 'सुरु हुँदै…';

  @override
  String mcpStatusRunning(String url) {
    return '$url मा सुनिरहेको';
  }

  @override
  String mcpStatusFailed(String error) {
    return 'सुरु गर्न सकिएन: $error';
  }

  @override
  String mcpStatusFallback(int preferred, int port) {
    return 'पोर्ट $preferred व्यस्त थियो, त्यसैले अहिले $port प्रयोग हुँदैछ। $preferred का लागि सेट गरिएका क्लाइन्ट त्यो खाली नभएसम्म जडान हुँदैनन्।';
  }

  @override
  String get mcpToken => 'पहुँच टोकन';

  @override
  String get mcpTokenBody =>
      'क्लाइन्टले हरेक अनुरोधसँग यो पठाउँछ। यो भएका जोकोहीले सोध्न सक्छन्; स्वीकृति तपाईं मात्र दिन सक्नुहुन्छ।';

  @override
  String get mcpTokenShow => 'टोकन देखाउनुहोस्';

  @override
  String get mcpTokenHide => 'टोकन लुकाउनुहोस्';

  @override
  String get mcpTokenCopy => 'टोकन कपी गर्नुहोस्';

  @override
  String get mcpTokenRegenerate => 'नयाँ टोकन बनाउनुहोस्';

  @override
  String get mcpTokenRegenerateTitle => 'पहुँच टोकन नयाँ बनाउने?';

  @override
  String get mcpTokenRegenerateBody =>
      'हालको टोकनसँग सेट गरिएका सबै क्लाइन्टले नयाँ टोकन नपाएसम्म काम गर्न छोड्छन्।';

  @override
  String get mcpCopied => 'कपी भयो';

  @override
  String get mcpSetupTitle => 'क्लाइन्ट जडान गर्नुहोस्';

  @override
  String get mcpSetupClaude => 'Claude Code';

  @override
  String get mcpSetupJson => 'अन्य क्लाइन्ट (JSON)';

  @override
  String get mcpActivity => 'गतिविधि';

  @override
  String mcpActivityBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कल रेकर्ड भए',
      one: '1 कल रेकर्ड भयो',
      zero: 'अहिलेसम्म कुनै कल छैन',
    );
    return '$_temp0';
  }

  @override
  String get mcpActivityTitle => 'MCP गतिविधि';

  @override
  String get mcpActivityEmpty =>
      'अहिलेसम्म कुनै कल छैन। सहायकले गर्ने हरेक कल यहाँ देखिन्छ।';

  @override
  String get mcpActivityClear => 'लग खाली गर्नुहोस्';

  @override
  String get mcpActivityClearTitle => 'गतिविधि लग खाली गर्ने?';

  @override
  String mcpActivityBytes(String size) {
    return '$size फर्काइयो';
  }

  @override
  String get mcpDecisionRead => 'पढियो';

  @override
  String get mcpDecisionApproved => 'स्वीकृत';

  @override
  String get mcpDecisionRemembered => 'स्वीकृत (सम्झिएको)';

  @override
  String get mcpDecisionDenied => 'अस्वीकृत';

  @override
  String get mcpDecisionTimedOut => 'जवाफ आएन';

  @override
  String get mcpDecisionUnavailable => 'देखाइएन';

  @override
  String get mcpDecisionRejected => 'अस्वीकार गरियो';

  @override
  String mcpApprovalTitle(String client, String action) {
    return '$client $action चाहन्छ';
  }

  @override
  String get mcpActionRunCommand => 'कमान्ड चलाउन';

  @override
  String get mcpActionSendInput => 'सेसनमा टाइप गर्न';

  @override
  String get mcpActionOpenSession => 'सेसन खोल्न';

  @override
  String get mcpActionStartTunnel => 'टनेल सुरु गर्न';

  @override
  String get mcpActionStopTunnel => 'टनेल रोक्न';

  @override
  String get mcpActionRunSnippet => 'स्निपेट चलाउन';

  @override
  String get mcpActionDownload => 'फाइल डाउनलोड गर्न';

  @override
  String get mcpActionUpload => 'फाइल अपलोड गर्न';

  @override
  String mcpActionOther(String tool) {
    return '$tool प्रयोग गर्न';
  }

  @override
  String get mcpApprovalTarget => 'कहाँ';

  @override
  String get mcpApprovalNote =>
      'यो नाम क्लाइन्टले आफैँ भनेको हो। तपाईंले सहायकलाई यो गर्न भन्नुभएको हो भने मात्र स्वीकृति दिनुहोस्।';

  @override
  String mcpApprovalRemember(int minutes) {
    return 'यो सेसनमा $minutes मिनेटसम्म नसोधी यो अनुमति दिनुहोस्';
  }

  @override
  String get mcpApprovalApprove => 'स्वीकृति दिनुहोस्';

  @override
  String get mcpApprovalDeny => 'अस्वीकार गर्नुहोस्';

  @override
  String get mcpDetailCommand => 'कमान्ड';

  @override
  String get mcpDetailInput => 'किस्ट्रोक';

  @override
  String get mcpDetailHost => 'होस्ट';

  @override
  String get mcpDetailTunnel => 'टनेल';

  @override
  String get mcpDetailSnippet => 'स्निपेट';

  @override
  String get mcpDetailRemotePath => 'सर्भरमा';

  @override
  String get mcpDetailLocalPath => 'यो कम्प्युटरमा';

  @override
  String get mcpDetailOverwrite => 'फाइल पहिल्यै भए त्यसलाई बदल्छ';
}
