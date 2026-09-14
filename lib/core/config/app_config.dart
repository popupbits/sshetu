/// Compile-time configuration.
///
/// Values can be overridden per build with `--dart-define`:
///
/// ```sh
/// flutter build apk --dart-define=APP_NAME=SSHetu\ Nightly
/// ```
abstract final class AppConfig {
  static const String appName = 'SSHetu';

  /// Android applicationId / iOS bundle id. Must match the Gradle config —
  /// the store deep link is built from it.
  static const String androidApplicationId = 'com.popupbits.sshetu';

  static const String storeListingUrl =
      'https://play.google.com/store/apps/details?id=com.popupbits.sshetu';

  static const String legalese = '© 2026 SSHetu';
}
