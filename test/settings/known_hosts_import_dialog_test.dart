import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/ssh/host_key.dart';
import 'package:sshetu/core/ssh/known_hosts_file.dart';
import 'package:sshetu/core/ssh/known_hosts_store.dart';
import 'package:sshetu/features/import/known_hosts_import.dart';
import 'package:sshetu/features/settings/known_hosts_screen.dart';
import 'package:sshetu/features/settings/widgets/known_hosts_import_dialog.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../ssh/fixtures/known_hosts_fixture.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final parsed = parseKnownHosts(kKnownHostsFixture);
  final conflicting = previewKnownHostsImport(parsed, [
    KnownHostKey(
      hostname: 'bastion.example.net',
      port: 2222,
      keyType: 'ssh-rsa',
      fingerprint: kEcdsaFingerprint,
      trustedAt: DateTime.utc(2025),
    ),
  ], now: DateTime.utc(2026));

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final (label, size) in [
    ('phone', const Size(360, 740)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('$label: the preview lists counts, conflicts and skips', (
      tester,
    ) async {
      setSize(tester, size);
      bool? confirmed;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  confirmed = await showKnownHostsImportPreview(
                    context,
                    conflicting,
                    source: '/home/me/.ssh/known_hosts',
                  ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.knownHostsImportNew(7)), findsOneWidget);
      expect(find.text(l10n.knownHostsImportNewHashed(2)), findsOneWidget);
      expect(find.text(l10n.knownHostsImportConflicts(1)), findsOneWidget);
      expect(find.text('bastion.example.net:2222'), findsOneWidget);
      expect(
        find.text(l10n.knownHostsImportInFile('ssh-rsa $kRsaFingerprint')),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.knownHostsImportRevoked(1)),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          l10n.knownHostsImportMalformed(5, '12, 13, 14, 15, 17'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(KnownHostsImportDialog.confirmKey));
      await tester.tap(find.byKey(KnownHostsImportDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  }

  for (final (label, size, embedded) in [
    ('phone', const Size(360, 740), false),
    ('desktop tab', const Size(1280, 800), true),
  ]) {
    testWidgets('$label: the trusted-keys screen offers the import and '
        'labels hashed entries', (tester) async {
      setSize(tester, size);
      final store = InMemoryKnownHostsStore();
      await store.trust(
        KnownHostKey(
          hostname: kHashedExampleCom,
          port: 0,
          keyType: 'ssh-ed25519',
          fingerprint: kEd25519Fingerprint,
          trustedAt: DateTime.utc(2026),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [knownHostsProvider.overrideWith((ref) async => store)],
          child: app(KnownHostsScreen(embedded: embedded)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(KnownHostsScreen.importKey), findsOneWidget);
      expect(
        embedded
            ? find.text(l10n.knownHostsImport)
            : find.byTooltip(l10n.knownHostsImport),
        findsOneWidget,
      );
      expect(find.text(l10n.knownHostsHashedTitle), findsOneWidget);
      expect(find.textContaining('|1|'), findsNothing);
    });
  }

  testWidgets('nothing new: the import button is disabled', (tester) async {
    final empty = previewKnownHostsImport(
      parseKnownHosts('# only a comment\n'),
      const [],
      now: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      app(KnownHostsImportDialog(preview: empty, source: 'known_hosts')),
    );
    expect(find.text(l10n.knownHostsImportNothing), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(KnownHostsImportDialog.confirmKey),
    );
    expect(button.onPressed, isNull);
  });
}
