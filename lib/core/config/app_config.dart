import 'package:flutter/foundation.dart' show TargetPlatform, kDebugMode;
import 'package:path/path.dart' as p;

/// Compile-time configuration.
///
/// Values can be overridden per build with `--dart-define`:
///
/// ```sh
/// flutter build apk --dart-define=APP_NAME=SSHetu\ Nightly
/// ```
abstract final class AppConfig {
  static const String appName = 'SSHetu';

  /// The **release** Android applicationId / iOS bundle id. Must match the
  /// Gradle config — the store deep link is built from it, and a debug build
  /// links to the real listing too, so this is never the debug id. See
  /// [AppIdentity] for the id this build actually runs under.
  static const String androidApplicationId = 'com.popupbits.sshetu';

  static const String storeListingUrl =
      'https://play.google.com/store/apps/details?id=com.popupbits.sshetu';

  static const String legalese = '© 2026 SSHetu';
}

/// Which app this build is: the real SSHetu, or "SSHetu Debug".
///
/// A debug build is a separate app with its own identity on every platform —
/// its own application id, bundle id, Windows product name and GTK
/// application id — so it never opens the real install's database, settings
/// or keychain, and installs beside it. That is what lets anyone, automated
/// QA included, run a debug build on a machine holding someone's real hosts
/// and keys without touching them.
///
/// The native half of that lives in the platform projects (Gradle's debug
/// `applicationIdSuffix`, the Xcode Debug configuration, the Windows and Linux
/// CMake files) and moves every plugin that derives its storage from the app's
/// identity. This is the Dart half: the few places that write somewhere the
/// identity does not reach, read from one object.
///
/// **The [release] values are the identity existing users' data is stored
/// under. Changing any of them moves or orphans that data.** They are pinned
/// by `test/core/app_identity_test.dart`.
///
/// "SSHetu Debug" is a build name, not user-facing copy — like Flutter's own
/// DEBUG banner, it never appears in a build a user installs — so it is a
/// constant here rather than a string in the ARB files.
final class AppIdentity {
  const AppIdentity._({
    required this.isDebug,
    required this.displayName,
    required this.applicationId,
    required this.databaseFileName,
    required this.secretKeyPrefix,
  });

  /// The shipped app. Every value here is where real data already lives.
  static const AppIdentity release = AppIdentity._(
    isDebug: false,
    displayName: 'SSHetu',
    applicationId: 'com.popupbits.sshetu',
    databaseFileName: 'sshetu.db',
    secretKeyPrefix: '',
  );

  /// A debug build (`flutter run`, `flutter build --debug`).
  static const AppIdentity debug = AppIdentity._(
    isDebug: true,
    displayName: 'SSHetu Debug',
    applicationId: 'com.popupbits.sshetu.debug',
    databaseFileName: 'sshetu-debug.db',
    secretKeyPrefix: 'sshetu-debug.',
  );

  /// The identity for a build mode. Profile builds are release-shaped
  /// natively (Gradle's profile type, Xcode's Profile configuration and the
  /// CMake Profile config all keep the release identity), so they are
  /// release here too.
  static AppIdentity forMode({required bool debug}) =>
      debug ? AppIdentity.debug : AppIdentity.release;

  /// This build's identity.
  static const AppIdentity current = kDebugMode ? debug : release;

  final bool isDebug;

  /// The name native code uses for the window title and launcher label.
  final String displayName;

  /// Android applicationId, iOS/macOS bundle id, GTK application id.
  final String applicationId;

  /// The SQLite file. See [databasePath].
  final String databaseFileName;

  /// Put in front of every credential-store key.
  ///
  /// Empty for release — the keys stay exactly what they have always been.
  /// For debug it is belt and braces on most platforms, and the only
  /// separation on one: macOS keeps these in the legacy login keychain (see
  /// `KeychainSecretVault`), which every app shares and which is keyed by
  /// service and account, not by bundle id. Without a prefix a debug build
  /// would look up the real app's items, and macOS would ask the user to let
  /// it in.
  final String secretKeyPrefix;

  /// Whether this build keeps its database in application support on
  /// [platform], rather than in the documents directory.
  ///
  /// Debug always does. Release does on Windows and Linux, where "documents"
  /// is the user's own shared Documents folder — browsed, synced by OneDrive,
  /// tidied by other programs — and a database there can simply vanish. On
  /// Android and iOS the documents directory is the app's private container,
  /// and so it is on macOS, where the release app is sandboxed
  /// (`macos/Runner/Release.entitlements`): it stays there, where every
  /// install's data already is.
  bool keepsDatabaseInSupport(TargetPlatform platform) =>
      isDebug ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;

  /// Where the database lives.
  ///
  /// Release on Windows and Linux: `<application support>/sshetu.db` —
  /// `%APPDATA%\PopupBits\SSHetu\` beside the settings, and
  /// `$XDG_DATA_HOME/com.popupbits.sshetu/`. Earlier releases kept it in
  /// Documents; bootstrap moves it once (see [legacyDatabasePath] and
  /// `DatabaseMove`).
  ///
  /// Release elsewhere: `<documents>/sshetu.db`, exactly as every version so
  /// far has put it. See [keepsDatabaseInSupport].
  ///
  /// Debug: `<application support>/sshetu-debug.db`. Application support is
  /// app-specific on every platform and follows the debug identity, and the
  /// distinct file name keeps the two apart even if that identity were ever
  /// lost natively.
  ///
  /// The directories are asked for lazily, so a build only ever touches the
  /// one it uses.
  Future<String> databasePath({
    required TargetPlatform platform,
    required Future<String> Function() documentsDirectory,
    required Future<String> Function() supportDirectory,
  }) async => p.join(
    keepsDatabaseInSupport(platform)
        ? await supportDirectory()
        : await documentsDirectory(),
    databaseFileName,
  );

  /// Where releases before the move kept the database on [platform] —
  /// `<documents>/sshetu.db` — or null when this build has nothing to move
  /// from.
  ///
  /// Null for debug on every platform: a debug build has never lived in
  /// Documents, and the file there is the real app's.
  Future<String?> legacyDatabasePath({
    required TargetPlatform platform,
    required Future<String> Function() documentsDirectory,
  }) async => !isDebug && keepsDatabaseInSupport(platform)
      ? p.join(await documentsDirectory(), databaseFileName)
      : null;

  /// Why a debug build's application support directory is not its own, or
  /// null when it is (or when this platform's path cannot tell).
  ///
  /// Checked before anything is opened. If the native half of the debug
  /// identity is missing — a hand-built runner, a stale CMake cache, an edit
  /// that dropped it — the plugins that derive their storage from that
  /// identity (shared_preferences on Windows and Linux, the Windows
  /// credential file) would open the real app's files. Refusing to start is
  /// the only safe answer to that.
  ///
  /// iOS is not checked: its container path is a UUID and names no bundle id.
  /// Release is never checked — its paths are whatever they have always been.
  String? isolationProblem(TargetPlatform platform, String supportDirectory) {
    if (!isDebug) return null;
    // The platform's own path style, not the host's, so this reads a Windows
    // path correctly in a test running on Linux CI.
    final paths = p.Context(
      style: platform == TargetPlatform.windows
          ? p.Style.windows
          : p.Style.posix,
    );
    final segments = paths.split(paths.normalize(supportDirectory));
    final ok = switch (platform) {
      // %APPDATA%\<CompanyName>\<ProductName>, from the exe's version info.
      TargetPlatform.windows =>
        segments.isNotEmpty && segments.last == displayName,
      // $XDG_DATA_HOME/<GTK application id>.
      TargetPlatform.linux =>
        segments.isNotEmpty && segments.last == applicationId,
      // .../Application Support/<bundle id>, and /data/user/N/<package>/files.
      TargetPlatform.macOS ||
      TargetPlatform.android => segments.contains(applicationId),
      _ => true,
    };
    return ok
        ? null
        : 'This debug build resolved its app data folder to '
              '"$supportDirectory", which is not the "$displayName" folder. '
              'It would share data with the installed app, so it will not '
              'start. Rebuild from a clean build directory.';
  }
}
