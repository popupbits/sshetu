/// Compile-time configuration.
///
/// Values can be overridden per build with `--dart-define`, which is how a
/// staging build points at a different backend without a code change:
///
/// ```sh
/// flutter build apk --dart-define=APPWRITE_ENDPOINT=https://staging/v1
/// ```
abstract final class AppConfig {
  static const String appName = 'SSHetu';

  /// Android applicationId / iOS bundle id. Must match the Gradle config —
  /// the store deep link is built from it.
  static const String androidApplicationId = 'com.popupbits.sshetu';

  static const String storeListingUrl =
      'https://play.google.com/store/apps/details?id=com.popupbits.sshetu';

  static const String legalese = '© 2026 SSHetu';

  // --- Appwrite ---

  static const String appwriteEndpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://cloud.appwrite.io/v1',
  );

  static const String appwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT',
    defaultValue: 'sshetu',
  );

  static const String appwriteDatabaseId = String.fromEnvironment(
    'APPWRITE_DATABASE',
    defaultValue: 'sshetu',
  );
}
