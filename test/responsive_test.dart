import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/app.dart';
import 'package:sshetu/core/util/responsive.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/keys/keys_controller.dart';

/// The app adapts to width, not to operating system.
///
/// PROJECT.md sets a proof obligation: an important screen is checked at a
/// phone width *and* a desktop width. This is that check for the app shell,
/// and the pattern to copy for a feature screen — pump at both sizes and
/// assert on what actually renders, rather than trusting that a breakpoint
/// helper was called.
void main() {
  /// Pump the app at [size] logical pixels.
  ///
  /// The view is reset afterwards; leaking a surface size into the next test
  /// makes failures depend on execution order.
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        ],
        child: const SshetuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Either side of the 600 breakpoint in core/util/responsive.dart.
  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  testWidgets('a phone gets the bottom bar, not the rail', (tester) async {
    await pumpAt(tester, phone);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a desktop window gets the rail, not the bottom bar', (
    tester,
  ) async {
    await pumpAt(tester, desktop);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('content stays a readable column on a wide window', (
    tester,
  ) async {
    await pumpAt(tester, desktop);
    // Nothing may span the full 1440: prose and forms are capped so they do
    // not become one very long line.
    for (final element in find.byType(ContentWidth).evaluate()) {
      expect(
        tester.getSize(find.byElementPredicate((e) => e == element)).width,
        lessThan(desktop.width),
      );
    }
  });
}
