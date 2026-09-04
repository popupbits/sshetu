import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/router/router.dart';
import 'package:sshetu/core/router/routes.dart';
import 'package:sshetu/core/settings/settings_controller.dart';

/// Every route constant resolves to a route.
///
/// Found the hard way. `Routes.transferSend` said `/transfer/send` while the
/// router declared it as a child of the settings branch, where it actually
/// lives at `/settings/transfer/send`. Analysis is happy — both are strings —
/// the tests all passed, and tapping the row in Settings gave a red
/// "no routes for location" page on a real device.
///
/// This does not build the screens, only asks the router whether it can match
/// the path. That is the part a constant can get wrong.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
  });

  /// Concrete paths only — the parameterised ones are built by helpers with
  /// their own tests, and a literal `:id` matches nothing by design.
  const paths = <String>[
    Routes.initial,
    Routes.splash,
    Routes.hostNew,
    Routes.importOpenSsh,
    Routes.tunnelNew,
    Routes.about,
    Routes.knownHosts,
    Routes.diagnostics,
    Routes.transferSend,
    Routes.transferReceive,
  ];

  test('every route constant matches a declared route', () {
    final router = container.read(routerProvider);
    final configuration = router.configuration;

    for (final path in paths) {
      expect(
        configuration.findMatch(Uri.parse(path)).routes,
        isNotEmpty,
        reason:
            '$path resolves to nothing — the constant and the route '
            'declaration disagree',
      );
    }
  });
}
