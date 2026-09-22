import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/export/domain/json_import_plan.dart';
import 'package:sshetu/features/export/domain/portable_export.dart';
import 'package:sshetu/features/export/presentation/export_json_dialog.dart';
import 'package:sshetu/features/export/presentation/json_import_dialog.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'sample_config.dart';

void main() {
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

  final l10n = lookupAppLocalizations(const Locale('en'));

  // A device with the same server saved under another id, and no keys.
  final plan = JsonImportPlan.build(
    source: sampleExport(),
    local: PortableExport(
      exportedAt: t0,
      app: '',
      hosts: [
        SshHost(
          id: 'local-web',
          label: 'my web box',
          hostname: 'web1.internal',
          username: 'deploy',
          createdAt: t0,
          updatedAt: t0,
        ),
      ],
    ),
  );

  for (final (label, size) in [
    ('phone', const Size(360, 740)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('$label: the export dialog says there are no secrets', (
      tester,
    ) async {
      setSize(tester, size);
      ExportJsonChoice? choice;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => choice = await showDialog(
                context: context,
                builder: (_) => const ExportJsonDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.exportJsonTitle), findsOneWidget);
      expect(find.text(l10n.exportJsonNoSecrets), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(ExportJsonDialog.backupKey));
      await tester.pumpAndSettle();
      expect(choice, ExportJsonChoice.backupInstead);
    });

    testWidgets('$label: the import preview shows counts, conflicts, keys', (
      tester,
    ) async {
      setSize(tester, size);
      ConflictRule? rule;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => rule = await showDialog(
                context: context,
                builder: (_) =>
                    JsonImportDialog(plan: plan, source: 'export.json'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.importJsonHostsNew(1)), findsOneWidget);
      expect(find.text(l10n.importJsonConflicts(1)), findsOneWidget);
      expect(
        find.text(l10n.importJsonConflictRow('web-1', 'my web box')),
        findsOneWidget,
      );
      expect(find.text(l10n.importJsonMergeHelp), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.importJsonMissingKeysTitle),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(l10n.importJsonMissingKeysTitle), findsOneWidget);
      expect(find.text(identity.fingerprint!), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text(l10n.importJsonAddAsNew),
        -100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(l10n.importJsonAddAsNew));
      await tester.pumpAndSettle();
      expect(find.text(l10n.importJsonAddAsNewHelp), findsOneWidget);

      await tester.tap(find.byKey(JsonImportDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(rule, ConflictRule.addAsNew);
    });
  }

  testWidgets('nothing to import: the button is off', (tester) async {
    final same = JsonImportPlan.build(
      source: sampleExport(),
      local: sampleExport(),
    );
    await tester.pumpWidget(
      app(JsonImportDialog(plan: same, source: 'export.json')),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.importJsonNothing), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(JsonImportDialog.confirmKey),
    );
    expect(button.onPressed, isNull);
  });

  test('every problem has its own sentence', () {
    for (final problem in PortableExportProblem.values) {
      final text = portableExportProblemText(
        l10n,
        PortableExportException(problem, detail: 'hosts[0].id', version: 9),
      );
      expect(text, isNotEmpty);
    }
    expect(
      portableExportProblemText(
        l10n,
        const PortableExportException(
          PortableExportProblem.newerVersion,
          version: 2,
        ),
      ),
      contains('format version 2'),
    );
  });
}
