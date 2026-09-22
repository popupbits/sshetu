import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/ui/context_menu.dart';

/// Regression: on a phone the menu is a bottom sheet, and a sheet is capped at
/// part of the screen. A terminal tab's menu has nine entries; on a 360x640
/// phone they overflowed the cap and the last rows could not be reached.
void main() {
  testWidgets('a long menu in a phone sheet scrolls, and every row is '
      'reachable', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContextMenuRegion(
            title: 'tab',
            actions: () => [
              for (var i = 0; i < 12; i++)
                MenuAction(
                  label: 'Action $i',
                  icon: Icons.star,
                  onSelected: () => chosen = 'Action $i',
                ),
            ],
            child: const SizedBox.expand(child: Text('row')),
          ),
        ),
      ),
    );

    // Tests report Android, so a long press opens the sheet.
    await tester.longPress(find.text('row'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'no overflow');

    await tester.scrollUntilVisible(find.text('Action 11'), 50);
    await tester.tap(find.text('Action 11'));
    await tester.pumpAndSettle();
    expect(chosen, 'Action 11');
  });
}
