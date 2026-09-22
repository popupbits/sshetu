import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sshetu/core/bootstrap.dart';
import 'package:sshetu/core/config/app_config.dart';

/// A debug build is "SSHetu Debug", a separate app with its own data; a
/// release build is exactly the app existing users already have.
///
/// The release half of this file is the important half. Every value it pins
/// is where a real install's data already lives — change one and that data is
/// stranded on the next update, with nothing failing anywhere but here.
void main() {
  group('release identity — where existing installs keep their data', () {
    const release = AppIdentity.release;

    test('is the shipped app, unchanged', () {
      expect(release.isDebug, isFalse);
      expect(release.displayName, 'SSHetu');
      expect(release.applicationId, 'com.popupbits.sshetu');
      expect(release.applicationId, AppConfig.androidApplicationId);
      expect(release.databaseFileName, 'sshetu.db');
      expect(release.secretKeyPrefix, isEmpty);
    });

    test('keeps the database at exactly <documents>/sshetu.db', () async {
      var supportAsked = false;
      final path = await release.databasePath(
        documentsDirectory: () async => '/home/someone/Documents',
        supportDirectory: () async {
          supportAsked = true;
          return '/elsewhere';
        },
      );
      expect(path, p.join('/home/someone/Documents', 'sshetu.db'));
      expect(
        supportAsked,
        isFalse,
        reason: 'a release build has no business asking for another folder',
      );
    });

    test('is never refused at startup, whatever its folder', () {
      for (final platform in TargetPlatform.values) {
        expect(release.isolationProblem(platform, '/anything'), isNull);
      }
    });

    test('startup check asks the platform for nothing', () async {
      // No path_provider is registered in a unit test, so reaching for one
      // would throw. Returning cleanly is the proof it did not.
      await expectLater(ensureIdentityIsolated(release), completes);
    });
  });

  group('debug identity', () {
    const debug = AppIdentity.debug;

    test('is a different app in every respect that stores data', () {
      expect(debug.isDebug, isTrue);
      expect(debug.displayName, 'SSHetu Debug');
      expect(debug.applicationId, 'com.popupbits.sshetu.debug');
      expect(
        debug.databaseFileName,
        isNot(AppIdentity.release.databaseFileName),
      );
      expect(debug.secretKeyPrefix, isNotEmpty);
    });

    test(
      'keeps its database in its own app folder, under its own name',
      () async {
        var documentsAsked = false;
        final path = await debug.databasePath(
          documentsDirectory: () async {
            documentsAsked = true;
            return '/home/someone/Documents';
          },
          supportDirectory: () async => '/support/SSHetu Debug',
        );
        expect(path, p.join('/support/SSHetu Debug', 'sshetu-debug.db'));
        expect(
          documentsAsked,
          isFalse,
          reason: 'Documents is shared with the real app on a desktop',
        );
      },
    );

    group('refuses to start when its app folder is the real app\'s', () {
      test('Windows: %APPDATA%\\PopupBits\\<ProductName>', () {
        expect(
          debug.isolationProblem(
            TargetPlatform.windows,
            r'C:\Users\x\AppData\Roaming\PopupBits\SSHetu Debug',
          ),
          isNull,
        );
        expect(
          debug.isolationProblem(
            TargetPlatform.windows,
            r'C:\Users\x\AppData\Roaming\PopupBits\SSHetu',
          ),
          isNotNull,
        );
      });

      test('Linux: \$XDG_DATA_HOME/<application id>', () {
        expect(
          debug.isolationProblem(
            TargetPlatform.linux,
            '/home/x/.local/share/com.popupbits.sshetu.debug',
          ),
          isNull,
        );
        expect(
          debug.isolationProblem(
            TargetPlatform.linux,
            '/home/x/.local/share/com.popupbits.sshetu',
          ),
          isNotNull,
        );
      });

      test('macOS: .../Application Support/<bundle id>', () {
        expect(
          debug.isolationProblem(
            TargetPlatform.macOS,
            '/Users/x/Library/Containers/com.popupbits.sshetu.debug/Data/'
            'Library/Application Support/com.popupbits.sshetu.debug',
          ),
          isNull,
        );
        expect(
          debug.isolationProblem(
            TargetPlatform.macOS,
            '/Users/x/Library/Containers/com.popupbits.sshetu/Data/'
            'Library/Application Support/com.popupbits.sshetu',
          ),
          isNotNull,
        );
      });

      test('Android: /data/user/N/<package>/files', () {
        expect(
          debug.isolationProblem(
            TargetPlatform.android,
            '/data/user/0/com.popupbits.sshetu.debug/files',
          ),
          isNull,
        );
        expect(
          debug.isolationProblem(
            TargetPlatform.android,
            '/data/user/0/com.popupbits.sshetu/files',
          ),
          isNotNull,
        );
      });

      test('iOS is not checked: its container path names no bundle id', () {
        expect(
          debug.isolationProblem(
            TargetPlatform.iOS,
            '/var/mobile/Containers/Data/Application/0F1E/Library/'
            'Application Support',
          ),
          isNull,
        );
      });
    });
  });

  test('the mode picks the identity', () {
    expect(AppIdentity.forMode(debug: false), same(AppIdentity.release));
    expect(AppIdentity.forMode(debug: true), same(AppIdentity.debug));
    // Tests run in debug mode, so this build is the debug app.
    expect(AppIdentity.current, same(AppIdentity.debug));
  });
}
