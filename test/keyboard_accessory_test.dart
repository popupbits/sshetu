import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ssh_navigator/core/ui/keyboard_accessory.dart';

/// The modifier bar above a phone's keyboard, and why it once never appeared.
///
/// The bar was gated on `MediaQuery.viewInsetsOf(context).bottom > 0`, read
/// from inside a Scaffold body. That reads zero forever: a Scaffold that
/// resizes for the keyboard has already made room for it and hands the body a
/// MediaQuery with the bottom inset removed. The gate was in the one place
/// where it could not work, so the bar never showed on a real device — while
/// every naive test that pumped the widget outside a Scaffold passed.
///
/// So this test insists on the Scaffold. Without one it proves nothing.
void main() {
  // No platform override: the accessory itself is platform-agnostic — the
  // caller decides that a phone is a phone — and setting one here trips the
  // framework's "debug variable changed by the test" invariant, which is
  // checked before tearDown gets to put it back.
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(child: SizedBox.expand()),
            KeyboardAccessory(child: Text('modifiers')),
          ],
        ),
      ),
    ),
  );

  testWidgets('hidden while no keyboard is on screen', (tester) async {
    await pump(tester);
    expect(find.text('modifiers'), findsNothing);
  });

  testWidgets('shown inside a Scaffold body when the keyboard opens', (
    tester,
  ) async {
    await pump(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 700);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(
      find.text('modifiers'),
      findsOneWidget,
      reason: 'the Scaffold zeroes the body MediaQuery; ask the view instead',
    );
  });

  testWidgets('hides again when the keyboard closes', (tester) async {
    await pump(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 700);
    await tester.pumpAndSettle();
    expect(find.text('modifiers'), findsOneWidget);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('modifiers'), findsNothing);
  });
}
