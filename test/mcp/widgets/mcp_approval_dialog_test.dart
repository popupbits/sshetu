import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/mcp/domain/approval.dart';
import 'package:sshetu/features/mcp/widgets/mcp_approval_dialog.dart';
import 'package:sshetu/l10n/app_localizations.dart';

void main() {
  ApprovalRequest request({bool remember = true}) => ApprovalRequest(
    clientName: 'claude-code',
    toolName: 'run_command',
    target: 'web-1 — deploy@10.0.0.4:22 (session s-1)',
    details: [
      ApprovalDetail(
        ApprovalDetailKind.command,
        visibleText('sudo systemctl restart nginx\u0003'),
      ),
    ],
    canRememberSimilar: remember,
  );

  Future<Future<ApprovalDecision>> open(
    WidgetTester tester,
    ApprovalRequest r,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Future<ApprovalDecision> decision;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => decision = McpApprovalDialog.show(context, r),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return decision;
  }

  for (final width in [360.0, 1280.0]) {
    group('at ${width.toInt()}px', () {
      testWidgets('names the client, action, target and exact command', (
        tester,
      ) async {
        await open(tester, request(), width);
        expect(tester.takeException(), isNull);
        expect(find.text('claude-code wants to run a command'), findsOneWidget);
        expect(
          find.text('web-1 — deploy@10.0.0.4:22 (session s-1)'),
          findsOneWidget,
        );
        expect(
          find.text('sudo systemctl restart nginx<Ctrl-C>'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mcp.approval.remember')), findsOneWidget);
      });

      testWidgets('approve once', (tester) async {
        final decision = await open(tester, request(), width);
        await tester.tap(find.byKey(const Key('mcp.approval.approve')));
        await tester.pumpAndSettle();
        expect(await decision, ApprovalDecision.approveOnce);
        expect(find.byKey(const Key('mcp.approval')), findsNothing);
      });

      testWidgets('approve similar, only when ticked', (tester) async {
        final decision = await open(tester, request(), width);
        await tester.tap(find.byKey(const Key('mcp.approval.remember')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('mcp.approval.approve')));
        await tester.pumpAndSettle();
        expect(await decision, ApprovalDecision.approveSimilar);
      });

      testWidgets('deny', (tester) async {
        final decision = await open(tester, request(remember: false), width);
        expect(find.byKey(const Key('mcp.approval.remember')), findsNothing);
        await tester.tap(find.byKey(const Key('mcp.approval.deny')));
        await tester.pumpAndSettle();
        expect(await decision, ApprovalDecision.deny);
      });
    });
  }

  testWidgets('closes itself, as a denial, when the request expires', (
    tester,
  ) async {
    final r = request();
    final decision = await open(tester, r, 1280);
    r.expire();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mcp.approval')), findsNothing);
    expect(await decision, ApprovalDecision.deny);
    // The screen underneath is still there.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('Deny has the focus, so Enter cannot approve', (tester) async {
    await open(tester, request(), 1280);
    final deny = tester.widget<TextButton>(
      find.byKey(const Key('mcp.approval.deny')),
    );
    expect(deny.autofocus, isTrue);
  });

  // Not just the flag: the button that actually holds keyboard focus, and
  // what Enter does with it. Approve is the filled button, and looks like
  // the default — it must not be the one Enter presses.
  testWidgets(
    'Enter denies: keyboard focus is on Deny, not the filled Approve',
    (tester) async {
      final decision = await open(tester, request(), 1280);
      final focused = FocusManager.instance.primaryFocus!.context!;
      bool within(Key key) =>
          find
              .ancestor(
                of: find.byElementPredicate((e) => e == focused),
                matching: find.byKey(key),
              )
              .evaluate()
              .isNotEmpty ||
          (focused.widget.key == key);
      expect(within(const Key('mcp.approval.deny')), isTrue);
      expect(within(const Key('mcp.approval.approve')), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(await decision, ApprovalDecision.deny);
      expect(find.byKey(const Key('mcp.approval')), findsNothing);
    },
    variant: TargetPlatformVariant.desktop(),
  );
}
