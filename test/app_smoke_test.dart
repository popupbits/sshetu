import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_navigator/core/app.dart';
import 'package:ssh_navigator/core/settings/settings_controller.dart';
import 'package:appwrite/models.dart' as models;
import 'package:ssh_navigator/features/auth/auth_controller.dart';
import 'package:ssh_navigator/features/hosts/hosts_controller.dart';
import 'package:ssh_navigator/features/keys/keys_controller.dart';

/// The app builds, routes to its first screen, and renders without throwing.
///
/// Deliberately shallow. Its job is to fail loudly when a change breaks
/// startup — a missing provider override, a bad route table, a theme that
/// throws — not to assert anything about a particular screen.
void main() {
  testWidgets('SSH Navigator starts and renders its first screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          // The data providers are stubbed rather than backed by a real
          // database: sqflite does real I/O, and real I/O cannot complete
          // under testWidgets' fake async — the screen would sit on its
          // spinner until pumpAndSettle gave up. These tests are about
          // startup and layout, not data.
          hostsProvider.overrideWith((ref) => []),
          identitiesProvider.overrideWith((ref) => []),
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: const SshNavigatorApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

/// Reports "signed out" without touching the network.
///
/// The real controller calls `account.get()` from `build()`, and Flutter's
/// test HTTP client answers every request with a 400. Without this override
/// the test would be asserting on a network failure rather than on the app.
class _SignedOutAuthController extends AuthController {
  @override
  Future<models.User?> build() async => null;
}
