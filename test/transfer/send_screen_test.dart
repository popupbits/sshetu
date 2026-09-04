import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/core/providers.dart';
import 'package:sshetu/core/secrets/secret_vault.dart';
import 'package:sshetu/features/transfer/presentation/send_screen.dart';
import 'package:sshetu/features/transfer/transfer_providers.dart';
import 'package:sshetu/features/transfer/transfer_session.dart';
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

  Future<void> pump(
    WidgetTester tester, {
    required bool embedded,
    Future<void> Function()? permission,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          secretVaultProvider.overrideWithValue(InMemorySecretVault()),
          if (permission != null)
            listenPermissionProvider.overrideWithValue(permission),
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

  /// Lets the real I/O in `_restart` land.
  ///
  /// The screen reads the database before it opens anything, and that is
  /// genuine async work on the real event loop — fake-time pumps alone never
  /// give it a turn, so the screen would still be on its first frame.
  Future<void> settleIO(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
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

  group('while the OS has not answered', () {
    // The freeze this fixes: macOS holds the first `listen()` inside the
    // syscall until someone answers its dialog. Run on the UI isolate that
    // stops the app dead — no frames, no spinner, nothing to tap. Modelled
    // here by a permission step that simply never completes.
    final never = Completer<void>();

    testWidgets('the screen keeps painting and says what it waits on', (
      tester,
    ) async {
      await pump(tester, embedded: true, permission: () => never.future);
      await settleIO(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.transferStepPermission), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and can be abandoned without leaving the screen', (
      tester,
    ) async {
      await pump(tester, embedded: true, permission: () => never.future);
      await settleIO(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.transferCancel));
      await tester.pump();

      expect(find.text(l10n.transferNotStarted), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    });
  });

  testWidgets('a refused permission is shown, not swallowed', (tester) async {
    await pump(
      tester,
      embedded: true,
      permission: () async => throw const TransferException('No listening.'),
    );
    await settleIO(tester);

    expect(find.text('No listening.'), findsOneWidget);
  });
}
