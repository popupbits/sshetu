import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/ssh/key_generator.dart';
import 'package:sshetu/core/ssh/private_key_inspector.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/keys/keys_controller.dart';
import 'package:sshetu/features/keys/keys_screen.dart';
import 'package:sshetu/features/keys/widgets/paste_key_sheet.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../ssh/fixtures/pasted_keys.dart';

/// What a save would have written, without a database or a keychain.
class _Saved {
  _Saved(this.identity, this.privateKey, this.passphrase);

  final SshIdentity identity;
  final String? privateKey;
  final String? passphrase;
}

class _RecordingController extends IdentitiesController {
  _RecordingController(super.ref, this.saved);

  final List<_Saved> saved;

  @override
  Future<void> save(
    SshIdentity identity, {
    String? privateKey,
    String? passphrase,
  }) async => saved.add(_Saved(identity, privateKey, passphrase));
}

/// Keys screen → Paste key → check → save, at a phone and a desktop width.
void main() {
  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  late List<_Saved> saved;

  // Made once, outside the fake clock: RSA generation is real work.
  late PastedKey rsaPlain;
  late PastedKey edEnc;
  setUpAll(() {
    rsaPlain = pkcs1Rsa();
    edEnc = encryptedOpenSsh();
  });

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    List<SshIdentity> existing = const [],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    saved = [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identitiesProvider.overrideWith((ref) => existing),
          identitiesControllerProvider.overrideWith(
            (ref) => _RecordingController(ref, saved),
          ),
          // The real one runs on an isolate, which the fake clock of a widget
          // test never lets finish.
          keyInspectorProvider.overrideWithValue(
            (text, {passphrase}) async =>
                inspectPrivateKey(text, passphrase: passphrase),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: KeysScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('keys-empty-paste')));
    await tester.pumpAndSettle();
    expect(find.text('Paste a private key'), findsOneWidget);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [('phone', phone), ('desktop', desktop)]) {
    group('at $name width', () {
      testWidgets('an OpenSSH key is checked, previewed, then saved', (
        tester,
      ) async {
        final generated = SshKeyGenerator.ed25519(comment: 'laptop');
        await pump(tester, size);
        await openSheet(tester);

        await enter(tester, 'paste-key-field', generated.privateKey);
        await tapKey(tester, 'paste-check');

        // The derived public half, shown before anything is stored.
        expect(find.byKey(const ValueKey('paste-preview')), findsOneWidget);
        expect(find.text(generated.fingerprint), findsOneWidget);
        expect(find.text(generated.publicKey), findsOneWidget);
        expect(saved, isEmpty);

        // The key's own comment becomes the label unless one was typed.
        await tapKey(tester, 'paste-save');

        expect(saved, hasLength(1));
        final entry = saved.single;
        expect(entry.identity.label, 'laptop');
        expect(entry.identity.keyType, 'ssh-ed25519');
        expect(entry.identity.fingerprint, generated.fingerprint);
        expect(entry.identity.publicKey, generated.publicKey);
        expect(entry.identity.hasPassphrase, isFalse);
        expect(entry.identity.origin, IdentityOrigin.imported);
        expect(entry.privateKey!.trim(), generated.privateKey.trim());
        expect(entry.passphrase, isNull);
        expect(find.text('Paste a private key'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a public key is refused with a clear message', (
        tester,
      ) async {
        await pump(tester, size);
        await openSheet(tester);

        await enter(tester, 'paste-key-field', rsaPlain.publicKey);
        await tapKey(tester, 'paste-check');

        expect(find.textContaining('That is a public key'), findsOneWidget);
        expect(find.byKey(const ValueKey('paste-save')), findsNothing);
        expect(saved, isEmpty);
      });

      testWidgets('garbage is refused', (tester) async {
        await pump(tester, size);
        await openSheet(tester);

        await enter(tester, 'paste-key-field', 'definitely not a key');
        await tapKey(tester, 'paste-check');

        expect(
          find.text("That doesn't look like a private key."),
          findsOneWidget,
        );
        expect(saved, isEmpty);
      });

      testWidgets('an encrypted key asks for its passphrase, and keeps it '
          'sealed', (tester) async {
        await pump(tester, size);
        await openSheet(tester);

        await enter(tester, 'paste-key-field', edEnc.pem);
        await tapKey(tester, 'paste-check');

        expect(
          find.byKey(const ValueKey('paste-passphrase-field')),
          findsOneWidget,
        );
        expect(find.textContaining('This key is protected'), findsOneWidget);

        await enter(tester, 'paste-passphrase-field', 'wrong');
        await tapKey(tester, 'paste-check');
        expect(
          find.text("That passphrase doesn't open this key."),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('paste-save')), findsNothing);

        await enter(tester, 'paste-passphrase-field', fixturePassphrase);
        await tapKey(tester, 'paste-check');
        expect(find.byKey(const ValueKey('paste-preview')), findsOneWidget);
        expect(find.textContaining('Passphrase-protected'), findsOneWidget);

        await enter(tester, 'paste-label-field', 'work');
        await tapKey(tester, 'paste-save');

        final entry = saved.single;
        expect(entry.identity.label, 'work');
        expect(entry.identity.hasPassphrase, isTrue);
        // Stored sealed, and the passphrase used to check it went nowhere.
        expect(SSHKeyPair.isEncryptedPem(entry.privateKey!), isTrue);
        expect(entry.passphrase, isNull);
      });

      testWidgets('a key already saved is pointed out, not duplicated', (
        tester,
      ) async {
        final generated = SshKeyGenerator.ed25519();
        final now = DateTime.utc(2026);
        await pump(
          tester,
          size,
          existing: [
            SshIdentity(
              id: 'k1',
              label: 'old laptop',
              keyType: 'ssh-ed25519',
              fingerprint: generated.fingerprint,
              publicKey: generated.publicKey,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );
        // The list is not empty, so the sheet opens the way the shell does.
        final context = tester.element(find.byType(KeysScreen));
        unawaited(showPasteKeySheet(context));
        await tester.pumpAndSettle();

        await enter(tester, 'paste-key-field', generated.privateKey);
        await tapKey(tester, 'paste-check');

        expect(
          find.text('You already have this key, as old laptop.'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('paste-save')), findsNothing);
      });
    });
  }
}
