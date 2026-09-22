import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/import/putty/putty_import.dart';
import 'package:sshetu/features/import/putty/putty_import_dialog.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'putty_fixture.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final candidates = PuttyImport.candidates(
    utf16leWithBom(kPuttyReg),
    const [],
  );

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  for (final (label, size) in [
    ('phone', const Size(360, 740)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('$label: preview, select, import', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      PuttyChoice? choice;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => choice = await showDialog(
                context: context,
                builder: (_) => PuttyImportDialog(
                  candidates: candidates,
                  source: 'sessions.reg',
                  username: 'localme',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('My Server'), findsOneWidget);
      expect(find.text(l10n.puttySkippedProtocol('telnet')), findsOneWidget);
      expect(find.text(l10n.puttySkippedNoHost), findsOneWidget);
      expect(
        find.text(l10n.puttyProxy('SOCKS5 proxy.corp:1080')),
        findsOneWidget,
      );
      expect(find.text(l10n.puttyForwards(4)), findsOneWidget);
      expect(find.text(l10n.puttyNoUsername('localme')), findsOneWidget);
      expect(find.text(l10n.puttyImportAction(3)), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(l10n.puttyPpkTitle),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(l10n.puttyPpkBody('My Server')), findsOneWidget);

      // Untick one; the count follows.
      await tester.scrollUntilVisible(
        find.text('bastion'),
        -100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('bastion'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.puttyImportAction(2)), findsOneWidget);

      await tester.tap(find.byKey(PuttyImportDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(choice!.pickFile, isFalse);
      expect(choice!.sessions.map((s) => s.name), ['My Server', 'Café box']);
    });
  }

  testWidgets('a skipped session cannot be ticked', (tester) async {
    await tester.pumpWidget(
      app(
        PuttyImportDialog(
          candidates: candidates,
          source: 'sessions.reg',
          username: 'localme',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final telnet = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('router telnet'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(telnet.value, isFalse);
    expect(telnet.onChanged, isNull);
  });
}
