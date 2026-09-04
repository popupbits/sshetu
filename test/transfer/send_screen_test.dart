import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/transfer/presentation/send_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import '../support/test_database.dart';

/// The send screen, pumped the way the workspace builds it.
///
/// Written to reproduce a freeze reported on a real desktop: tapping "Send to
/// a device" locked the app up. A screen that never settles is a screen whose
/// `pumpAndSettle` never returns, so this test either passes quickly or hangs
/// exactly the way the app did.
void main() {
  late AppDatabase database;

  setUp(() async => database = await openTestDatabase());
  tearDown(() async => database.raw.close());

  Future<void> pump(WidgetTester tester, {required bool embedded}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretVaultProvider.overrideWithValue(InMemorySecretVault()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: TransferSendScreen(embedded: embedded)),
        ),
      ),
    );
  }

  testWidgets('settles instead of spinning forever', (tester) async {
    await pump(tester, embedded: true);

    // The screen opens a real listener, so give the async work a few turns.
    // If it never settles, this is the reported freeze.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded, it draws no app bar of its own', (tester) async {
    await pump(tester, embedded: true);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('standalone, it does', (tester) async {
    await pump(tester, embedded: false);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AppBar), findsOneWidget);
  });
}
