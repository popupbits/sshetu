import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/app.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/keys/domain/ssh_identity.dart';
import 'package:sshetu/features/keys/keys_controller.dart';
import 'package:sshetu/features/palette/widgets/command_palette.dart';
import 'package:sshetu/features/snippets/domain/snippet.dart';
import 'package:sshetu/features/snippets/snippets_controller.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';
import 'package:sshetu/features/tunnels/tunnels_controller.dart';

/// The palette reached the way a person reaches it, in the real app: the
/// search button on a phone, Ctrl+K on a desktop — and a choice that actually
/// takes you somewhere.
void main() {
  final now = DateTime.utc(2026, 1, 1);

  Future<void> pumpApp(WidgetTester tester, Size size) async {
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
          hostsProvider.overrideWith(
            (ref) => [
              SshHost(
                id: 'h1',
                label: 'bastion',
                hostname: '10.0.0.4',
                username: 'root',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
          identitiesProvider.overrideWith((ref) => const <SshIdentity>[]),
          tunnelsProvider.overrideWith((ref) => const <Tunnel>[]),
          snippetsProvider.overrideWith((ref) => const <Snippet>[]),
        ],
        child: const SshetuApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a phone opens it full-screen from the app bar', (tester) async {
    await pumpApp(tester, const Size(360, 640));

    await tester.tap(find.byKey(const Key('shell.openPalette')));
    await tester.pumpAndSettle();

    expect(find.byType(CommandPalette), findsOneWidget);
    expect(tester.getSize(find.byType(CommandPalette)).width, 360);
    expect(find.byKey(const Key('palette.item.host:h1')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const Key('palette.search')), 'go keys');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('palette.item.goto:keys')));
    await tester.pumpAndSettle();

    expect(find.byType(CommandPalette), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Keys')),
      findsOneWidget,
    );
  });

  testWidgets('a desktop opens it with Ctrl+K outside a terminal', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await pumpApp(tester, const Size(1280, 800));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(CommandPalette), findsOneWidget);
      expect(
        tester.getSize(find.byType(CommandPalette)).width,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.byKey(const Key('palette.search')),
        'settings about',
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(CommandPalette), findsNothing);
      // Settings, scrolled down to the last section — far below the fold of
      // an unscrolled list — so the request was answered, not luck.
      final about = find.text('ABOUT');
      expect(about, findsOneWidget);
      final top = tester.getTopLeft(about).dy;
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(800));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
