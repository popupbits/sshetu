import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Apple-side store answers that live in files rather than in code.
///
/// Every one of these compiles, analyzes and tests green while being wrong.
/// They fail instead at App Store Connect, at review, or — worse — on a
/// stranger's phone, where a missing purpose string is not an error message
/// but a feature that quietly does nothing. A string search is a crude test
/// of a plist; it is a precise test of a line that must not be lost.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path — run from the root');
    return file.readAsStringSync().replaceAll('\r\n', '\n');
  }

  /// The `<string>` (or `<true/>`/`<false/>`) that follows [key] in a plist.
  String? valueFor(String plist, String key) {
    final match = RegExp(
      '<key>$key</key>\\s*(?:<!--[\\s\\S]*?-->\\s*)*'
      '(<string>([\\s\\S]*?)</string>|<true/>|<false/>)',
    ).firstMatch(plist);
    if (match == null) return null;
    return match.group(2) ?? match.group(1);
  }

  group('iOS Info.plist', () {
    late String plist;
    setUp(() => plist = read('ios/Runner/Info.plist'));

    // Guideline 5.1.1(ii): the string has to describe the specific use.
    // Boilerplate is rejected, and an absent one means the feature is denied
    // by the system with nothing to show the user.
    test('every permission the app actually triggers has a purpose string', () {
      for (final key in [
        // mobile_scanner, for the device-transfer QR code.
        'NSCameraUsageDescription',
        // local_auth, for the optional credential lock.
        'NSFaceIDUsageDescription',
        // Connecting to a server at a private address, and the direct
        // device-to-device transfer. Both are local-network traffic, which
        // iOS 14+ refuses outright without this key.
        'NSLocalNetworkUsageDescription',
      ]) {
        final value = valueFor(plist, key);
        expect(value, isNotNull, reason: '$key is missing');
        expect(
          value!.trim().length,
          greaterThan(40),
          reason: '$key reads like boilerplate; say what it is for',
        );
      }
    });

    // Nothing browses or advertises over mDNS — the receiver reads the
    // sender's address straight out of the QR code. A Bonjour declaration
    // with no Bonjour behind it is a question at review for no gain.
    test('declares no Bonjour services, because nothing uses them', () {
      expect(plist, isNot(contains('<key>NSBonjourServices</key>')));
    });

    // An SSH client carries its own ciphers, so none of App Store Connect's
    // exemptions apply and the answer is true. The PopupBits default of
    // false is for apps whose only encryption is Apple's; shipping it here
    // would be a false declaration on a US export form.
    // See RELEASE_READINESS.md.
    test('answers the export-compliance question, and answers it true', () {
      expect(
        valueFor(plist, 'ITSAppUsesNonExemptEncryption'),
        '<true/>',
        reason:
            'SSHetu implements SSH transport encryption itself; it is not '
            'exempt, and leaving the key out makes App Store Connect ask on '
            'every single upload',
      );
    });
  });

  group('the privacy manifest', () {
    // Required since May 2024. This one fails at *upload*, before a human
    // has looked at the app, which is why it is worth a test.
    test('exists and declares no collection and no tracking', () {
      final manifest = read('ios/Runner/PrivacyInfo.xcprivacy');
      expect(manifest, contains('<key>NSPrivacyTracking</key>'));
      expect(
        RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(manifest),
        isTrue,
        reason: 'SSHetu has no backend and no analytics',
      );
      expect(
        RegExp(r'<key>NSPrivacyCollectedDataTypes</key>\s*<array\s*/>')
            .hasMatch(manifest),
        isTrue,
        reason:
            'nothing is collected; this must stay in step with the App '
            'Privacy answers in RELEASE_READINESS.md',
      );
      // The required-reason APIs the app itself touches.
      expect(manifest, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
      expect(manifest, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    });

    // A manifest that is not in the target's Resources build phase is not in
    // the app, and nothing at build time says so.
    test('is a resource of the Runner target', () {
      final project = read('ios/Runner.xcodeproj/project.pbxproj');
      expect(
        project,
        contains('/* PrivacyInfo.xcprivacy */ = {isa = PBXFileReference'),
        reason: 'the file is not referenced by the Xcode project',
      );
      final resources = RegExp(
        r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{[\s\S]*?\};',
      ).firstMatch(project)?.group(0);
      expect(resources, isNotNull, reason: "Runner's Resources phase moved");
      expect(
        resources,
        contains('PrivacyInfo.xcprivacy in Resources'),
        reason:
            'the manifest is referenced but never copied into the bundle, '
            'which is indistinguishable from not having one',
      );
    });
  });

  group('macOS Info.plist', () {
    late String plist;
    setUp(() => plist = read('macos/Runner/Info.plist'));

    test('has the camera and local-network strings the Mac build needs', () {
      // macOS 15 brought the local-network prompt to the Mac, and this app
      // trips it connecting to a LAN host and sending to a device.
      for (final key in [
        'NSCameraUsageDescription',
        'NSLocalNetworkUsageDescription',
      ]) {
        expect(valueFor(plist, key), isNotNull, reason: '$key is missing');
      }
    });

    // Both entitlement files must agree: a release that omits
    // network.client ships a Mac app that cannot open a single socket, and
    // no debug run would reveal it. See docs/macos-sandbox.md.
    test('release and debug entitlements agree on what the app may do', () {
      final release = read('macos/Runner/Release.entitlements');
      final debug = read('macos/Runner/DebugProfile.entitlements');
      for (final entitlement in [
        'com.apple.security.app-sandbox',
        'com.apple.security.network.client',
        'com.apple.security.network.server',
        'com.apple.security.device.camera',
        'com.apple.security.files.user-selected.read-write',
      ]) {
        expect(release, contains(entitlement), reason: 'release: $entitlement');
        expect(debug, contains(entitlement), reason: 'debug: $entitlement');
      }
      // allow-jit is the one difference, and it belongs to debug alone.
      expect(debug, contains('com.apple.security.cs.allow-jit'));
      expect(release, isNot(contains('com.apple.security.cs.allow-jit')));
    });
  });
}
