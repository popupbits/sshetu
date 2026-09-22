import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The native half of "debug builds have their own identity", read from the
/// platform projects.
///
/// Every assertion about **release** here pins the identity existing users'
/// data is filed under: the Android applicationId, the iOS and macOS bundle
/// id, the Windows product name (which names the %APPDATA% folder) and the
/// GTK application id (which names the Linux data folder and keyring schema).
/// Any of them changing in a release build strands that data on the next
/// update, and no build or analyzer would say a word.
///
/// A string search is a crude test of a build file, but it is a precise test
/// of the one line that must not move.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path — run from the root');
    return file.readAsStringSync().replaceAll('\r\n', '\n');
  }

  /// The body of the first `name { ... }` block after [from], braces
  /// balanced.
  String block(String source, String name, {int from = 0}) {
    final start = RegExp('\\b$name\\s*(\\([^)]*\\))?\\s*\\{')
        .allMatches(source, from)
        .first;
    var depth = 0;
    for (var i = start.end - 1; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}' && --depth == 0) {
        return source.substring(start.end, i);
      }
    }
    fail('unbalanced $name block');
  }

  group('Android', () {
    late String gradle;
    setUp(() => gradle = read('android/app/build.gradle.kts'));

    test('release keeps applicationId com.popupbits.sshetu', () {
      final defaults = block(gradle, 'defaultConfig');
      expect(defaults, contains('applicationId = "com.popupbits.sshetu"'));
      expect(defaults, contains('manifestPlaceholders["appLabel"] = "SSHetu"'));
    });

    test('the .debug suffix is on the debug build type and nowhere else', () {
      final buildTypes = block(gradle, 'buildTypes');
      final debug = block(buildTypes, 'debug');
      expect(debug, contains('applicationIdSuffix = ".debug"'));
      expect(
        debug,
        contains('manifestPlaceholders["appLabel"] = "SSHetu Debug"'),
      );

      expect(
        '.debug"'.allMatches(gradle).length,
        1,
        reason: 'exactly one applicationIdSuffix, the debug one',
      );
      expect(block(buildTypes, 'release'), isNot(contains('applicationId')));
      expect(
        block(buildTypes, 'getByName'),
        contains('applicationIdSuffix = null'),
      );
    });

    test('the manifest label comes from the build type', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains(r'android:label="${appLabel}"'));
    });
  });

  group('iOS', () {
    late String project;
    setUp(() => project = read('ios/Runner.xcodeproj/project.pbxproj'));

    List<String> bundleIds(String config) => [
      for (final match in RegExp(
        '/\\* $config \\*/ = \\{[^}]*?PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
      ).allMatches(project))
        match.group(1)!,
    ].where((id) => !id.endsWith('RunnerTests')).toList();

    test('Release and Profile keep com.popupbits.sshetu', () {
      expect(bundleIds('Release'), ['com.popupbits.sshetu']);
      expect(bundleIds('Profile'), ['com.popupbits.sshetu']);
    });

    test('Debug is com.popupbits.sshetu.debug', () {
      expect(bundleIds('Debug'), ['com.popupbits.sshetu.debug']);
    });

    test('the display name follows the configuration', () {
      expect(
        read('ios/Runner/Info.plist'),
        contains(r'<string>$(APP_DISPLAY_NAME)</string>'),
      );
      expect(
        read('ios/Flutter/Release.xcconfig'),
        contains('APP_DISPLAY_NAME = SSHetu\n'),
      );
      expect(
        read('ios/Flutter/Debug.xcconfig'),
        contains('APP_DISPLAY_NAME = SSHetu Debug'),
      );
    });
  });

  group('macOS', () {
    test('the base bundle id — Release and Profile — is unchanged', () {
      final info = read('macos/Runner/Configs/AppInfo.xcconfig');
      expect(
        info,
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.popupbits.sshetu\n'),
      );
      expect(info, contains('PRODUCT_NAME = SSHetu\n'));
    });

    test('only the Runner Debug configuration overrides it', () {
      final project = read('macos/Runner.xcodeproj/project.pbxproj');
      final overrides = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = com\.popupbits\.sshetu(\.debug)?;',
      ).allMatches(project).map((m) => m.group(0)).toList();
      expect(overrides, [
        'PRODUCT_BUNDLE_IDENTIFIER = com.popupbits.sshetu.debug;',
      ]);
      final debugConfig = RegExp(
        r'/\* Debug \*/ = \{[^}]*?CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile'
        r'[\s\S]*?name = Debug;',
      ).firstMatch(project)!.group(0)!;
      expect(debugConfig, contains('com.popupbits.sshetu.debug'));
    });
  });

  group('Windows', () {
    test('ProductName — the %APPDATA% folder — is SSHetu outside Debug', () {
      final identity = read('windows/runner/app_identity.h');
      final release = identity.substring(identity.indexOf('#else'));
      expect(release, contains('#define SSHETU_PRODUCT_NAME "SSHetu"\n'));
      expect(
        read('windows/runner/Runner.rc'),
        contains('VALUE "ProductName", SSHETU_PRODUCT_NAME'),
      );
      expect(read('windows/runner/Runner.rc'), contains('"PopupBits"'));
    });

    test('the debug name is switched on for the Debug config only', () {
      expect(
        read('windows/runner/CMakeLists.txt'),
        contains(r'"$<$<CONFIG:Debug>:SSHETU_DEBUG_IDENTITY>"'),
      );
    });
  });

  group('Linux', () {
    test('APPLICATION_ID is com.popupbits.sshetu, suffixed only in Debug', () {
      final cmake = read('linux/CMakeLists.txt');
      expect(cmake, contains('set(APPLICATION_ID "com.popupbits.sshetu")'));
      final debug = RegExp(
        r'if\(CMAKE_BUILD_TYPE STREQUAL "Debug"\)([\s\S]*?)endif\(\)',
      ).firstMatch(cmake);
      expect(debug, isNotNull);
      expect(
        debug!.group(1),
        contains(r'set(APPLICATION_ID "${APPLICATION_ID}.debug")'),
      );
      // Set before the runner and the plugins read it.
      expect(
        cmake.indexOf('.debug")'),
        lessThan(cmake.indexOf('add_subdirectory("runner")')),
      );
      expect(
        cmake.indexOf('.debug")'),
        lessThan(cmake.indexOf('generated_plugins.cmake')),
      );
    });
  });
}
