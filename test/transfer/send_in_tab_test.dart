import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';
import 'package:sshetu/features/transfer/presentation/send_screen.dart';
import 'package:sshetu/features/transfer/transfer_providers.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/test_database.dart';

/// The send screen as a workspace tab, which is how a desktop actually opens
/// it — and the shape the freeze was reported against.
///
/// Opened as a plain route the same screen is fine, so what this pins down is
/// the tab: does putting it in the pane make it start over and over?
void main() {
  late AppDatabase database;

  setUp(() async => database = await openTestDatabase());
  tearDown(() async => database.raw.close());

  testWidgets('a send tab starts exactly one listener', (tester) async {
    var starts = 0;

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secretVaultProvider.overrideWithValue(InMemorySecretVault()),
        // Counting the permission step counts the starts: every start goes
        // through it, and nothing else does.
        listenPermissionProvider.overrideWithValue(() async => starts++),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(body: TerminalWorkspace()),
        ),
      ),
    );

    container.read(workspacePagesProvider.notifier).open(
      WorkspacePage(
        id: 'transfer/send',
        title: 'Send',
        icon: PiconsRegular.qrCode,
        builder: (_) => const TransferSendScreen(embedded: true),
      ),
    );

    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(find.byType(TransferSendScreen), findsOneWidget);
    expect(starts, 1, reason: 'the tab restarted the transfer $starts times');

    // Close the tab and let the listener go: a real socket was opened, and
    // its wait holds a timer the test binding checks for at teardown.
    container.read(workspacePagesProvider.notifier).close('transfer/send');
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  });
}
