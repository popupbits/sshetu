import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/config/app_config.dart';
import 'package:sshetu/core/ui/debug_badge.dart';

/// The DEBUG pill: there in a debug build, so a screenshot cannot pass for
/// release; absent — not merely hidden — in a release build, so release lays
/// out exactly as it did before the pill existed.
void main() {
  Future<void> pump(WidgetTester tester, AppIdentity identity) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: DebugBadge(identity: identity)),
          ),
        ),
      );

  testWidgets('a debug build shows it', (tester) async {
    await pump(tester, AppIdentity.debug);
    expect(find.text('DEBUG'), findsOneWidget);
    expect(find.byKey(const Key('debugBadge')), findsOneWidget);
  });

  testWidgets('a release build draws nothing', (tester) async {
    await pump(tester, AppIdentity.release);
    expect(find.text('DEBUG'), findsNothing);
    expect(
      tester.getSize(find.byType(DebugBadge)),
      Size.zero,
      reason: 'a zero-size box, so the rail and About screen are unchanged',
    );
  });
}
