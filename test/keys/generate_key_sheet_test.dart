import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/ssh/key_generator.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/keys/keys_controller.dart';
import 'package:sshetu/features/keys/widgets/generate_key_sheet.dart';
import 'package:sshetu/l10n/app_localizations.dart';

class _RecordingController extends IdentitiesController {
  _RecordingController(super.ref, this.saved);

  final List<(SshIdentity, String?, String?)> saved;

  @override
  Future<void> save(
    SshIdentity identity, {
    String? privateKey,
    String? passphrase,
  }) async => saved.add((identity, privateKey, passphrase));
}

/// The generate sheet: type choice, the optional passphrase, and what is
/// saved.
void main() {
  late List<(SshIdentity, String?, String?)> saved;
  late List<(SshKeyType, String?)> requested;

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    saved = [];
    requested = [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identitiesControllerProvider.overrideWith(
            (ref) => _RecordingController(ref, saved),
          ),
          // Synchronous, and with cheap bcrypt: this is about the sheet.
          keyGeneratorProvider.overrideWithValue((
            type, {
            comment = '',
            passphrase,
          }) async {
            requested.add((type, passphrase));
            return SshKeyGenerator.generate(
              type == SshKeyType.rsa3072 || type == SshKeyType.rsa4096
                  ? SshKeyType.ed25519
                  : type,
              comment: comment,
              passphrase: passphrase,
              rounds: 2,
            );
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: GenerateKeySheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('Ed25519 without a passphrase is the default ($name)', (
      tester,
    ) async {
      await pump(tester, size);
      expect(find.text('Ed25519 (recommended)'), findsOneWidget);

      await enter(tester, 'generate-label', 'phone');
      await tapKey(tester, 'generate-submit');

      expect(requested.single, (SshKeyType.ed25519, null));
      final (identity, pem, passphrase) = saved.single;
      expect(identity.keyType, 'ssh-ed25519');
      expect(identity.hasPassphrase, isFalse);
      expect(identity.origin, IdentityOrigin.generated);
      expect(SSHKeyPair.fromPem(pem!), hasLength(1));
      expect(passphrase, isNull);
      // Ends on the public key, to copy.
      expect(find.text(identity.publicKey!), findsOneWidget);
    });

    testWidgets('a passphrase must be repeated, and seals the key ($name)', (
      tester,
    ) async {
      await pump(tester, size);
      await enter(tester, 'generate-label', 'sealed');
      await enter(tester, 'generate-passphrase', 'secret one');
      await enter(tester, 'generate-passphrase-repeat', 'secret two');

      expect(find.text("The passphrases don't match."), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('generate-submit')),
      );
      expect(button.onPressed, isNull);

      await enter(tester, 'generate-passphrase-repeat', 'secret one');
      await tapKey(tester, 'generate-submit');

      final (identity, pem, passphrase) = saved.single;
      expect(identity.hasPassphrase, isTrue);
      expect(SSHKeyPair.isEncryptedPem(pem!), isTrue);
      expect(SSHKeyPair.fromPem(pem, 'secret one'), hasLength(1));
      // Not written to the vault: connecting asks for it.
      expect(passphrase, isNull);
    });
  }

  testWidgets('another type can be chosen', (tester) async {
    await pump(tester, const Size(390, 844));
    await enter(tester, 'generate-label', 'ec');
    await tapKey(tester, 'generate-type');
    await tester.tap(find.text('ECDSA P-256').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'generate-submit');

    expect(requested.single.$1, SshKeyType.ecdsaP256);
    expect(saved.single.$1.keyType, 'ecdsa-sha2-nistp256');
  });
}
