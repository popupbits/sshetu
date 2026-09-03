import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/hosts/hosts_screen.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The search field, and when it is worth showing.
///
/// A field for narrowing an empty list can do nothing but sit there, and on
/// an otherwise empty screen it is the heaviest element present — pulling the
/// eye away from the two buttons that are the entire point of that screen.
void main() {
  final now = DateTime.utc(2026, 1, 1);

  SshHost host(String label) => SshHost(
    id: label,
    label: label,
    hostname: '$label.example.com',
    username: 'root',
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pump(WidgetTester tester, List<SshHost> hosts) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hostsProvider.overrideWith((ref) => hosts)],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: HostsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no search field when there are no hosts at all', (tester) async {
    await pump(tester, []);

    expect(find.byType(SearchBar), findsNothing);
    // The way out of the empty state is still there.
    expect(find.text('Import from OpenSSH'), findsOneWidget);
  });

  testWidgets('a search field as soon as there is a host', (tester) async {
    await pump(tester, [host('bastion')]);

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('bastion'), findsOneWidget);
  });

  testWidgets('the field survives a query that matches nothing', (
    tester,
  ) async {
    // Otherwise the field disappears along with the results, taking the only
    // way to clear the query with it.
    await pump(tester, [host('bastion')]);

    await tester.enterText(find.byType(SearchBar), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('bastion'), findsNothing);
  });
}
