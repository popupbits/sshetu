import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/snippets/domain/snippet.dart';
import 'package:sshetu/features/snippets/snippet_delivery.dart';
import 'package:sshetu/features/snippets/snippets_controller.dart';
import 'package:sshetu/features/snippets/widgets/run_on_dialog.dart';
import 'package:sshetu/features/snippets/widgets/snippet_picker.dart';
import 'package:sshetu/features/snippets/widgets/snippet_variables_dialog.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:xterm2/xterm.dart';

/// The picker driven the way a person drives it, against sessions whose
/// terminals are captured instead of connected — so each test can say
/// exactly which bytes each session would have received.
void main() {
  final now = DateTime.utc(2026, 1, 1);

  Snippet snippet(String id, String label, String body) =>
      Snippet(id: id, label: label, body: body, createdAt: now, updatedAt: now);

  final snippets = [
    snippet('up', 'Uptime', 'uptime'),
    snippet('logs', 'Tail logs', 'cd /var/log\ntail -f syslog'),
    snippet('greet', 'Greet', 'echo {{host}} {{msg:hello}}'),
  ];

  ({SnippetTarget target, List<String> sent}) fake(
    String id, {
    bool live = true,
  }) {
    final terminal = Terminal();
    final sent = <String>[];
    terminal.onOutput = sent.add;
    return (
      target: SnippetTarget(
        id: id,
        title: id,
        terminal: terminal,
        isLive: live,
        host: '$id.example.com',
        user: 'deploy',
        port: 22,
      ),
      sent: sent,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required SnippetTarget current,
    List<SnippetTarget> targets = const [],
    Size size = const Size(1200, 800),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [snippetsProvider.overrideWith((ref) => snippets)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showSnippetPicker(
                  context,
                  ref,
                  current: current,
                  targets: targets,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Lets a toast run out, so no timer is left pending.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every snippet, and search narrows by body too', (
    tester,
  ) async {
    final a = fake('a');
    await pump(tester, current: a.target);

    expect(find.byType(SnippetPicker), findsOneWidget);
    expect(find.text('Uptime'), findsOneWidget);
    expect(find.text('Tail logs'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('snippetPicker.search')),
      'syslog',
    );
    await tester.pumpAndSettle();
    expect(find.text('Uptime'), findsNothing);
    expect(find.text('Tail logs'), findsOneWidget);
  });

  testWidgets('Insert types the command and presses nothing', (tester) async {
    final a = fake('a');
    await pump(tester, current: a.target);

    await tester.tap(find.byKey(const Key('snippetPicker.insert.up')));
    await tester.pumpAndSettle();

    expect(find.byType(SnippetPicker), findsNothing);
    expect(a.sent.join(), 'uptime');
  });

  testWidgets('Run types the command and then Enter', (tester) async {
    final a = fake('a');
    await pump(tester, current: a.target);

    await tester.tap(find.byKey(const Key('snippetPicker.run.up')));
    await tester.pumpAndSettle();

    expect(a.sent.join(), 'uptime\r');
  });

  testWidgets('a multi-line Run goes line by line', (tester) async {
    final a = fake('a');
    await pump(tester, current: a.target);

    await tester.tap(find.byKey(const Key('snippetPicker.run.logs')));
    await tester.pumpAndSettle();

    expect(a.sent, ['cd /var/log', '\r', 'tail -f syslog', '\r']);
  });

  testWidgets('a multi-line Insert into a shell without bracketed paste '
      'sends nothing and says why', (tester) async {
    final a = fake('a');
    await pump(tester, current: a.target);

    await tester.tap(find.byKey(const Key('snippetPicker.insert.logs')));
    await tester.pumpAndSettle();

    expect(a.sent, isEmpty);
    expect(find.textContaining('Use Run instead'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('user variables are asked once, prefilled with defaults, '
      'and built-ins come from the session', (tester) async {
    final a = fake('a');
    await pump(tester, current: a.target);

    await tester.tap(find.byKey(const Key('snippetPicker.run.greet')));
    await tester.pumpAndSettle();

    expect(find.byType(SnippetVariablesDialog), findsOneWidget);
    // {{host}} is a built-in, so only {{msg}} is a question.
    expect(find.byKey(const Key('snippetVariable.host')), findsNothing);
    final field = find.byKey(const Key('snippetVariable.msg'));
    expect(tester.widget<TextField>(field).controller!.text, 'hello');
    expect(find.text('echo a.example.com hello'), findsOneWidget);

    await tester.enterText(field, 'world');
    await tester.pumpAndSettle();
    expect(find.text('echo a.example.com world'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Run'));
    await tester.pumpAndSettle();

    expect(a.sent.join(), 'echo a.example.com world\r');
  });

  testWidgets('cancelling the variables sends nothing', (tester) async {
    final a = fake('a');
    await pump(tester, current: a.target);

    await tester.tap(find.byKey(const Key('snippetPicker.run.greet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(a.sent, isEmpty);
  });

  group('run on several sessions', () {
    testWidgets('not offered when this is the only live tab', (tester) async {
      final a = fake('a');
      final b = fake('b', live: false);
      await pump(tester, current: a.target, targets: [a.target, b.target]);

      expect(find.byKey(const Key('snippetPicker.runOn.up')), findsNothing);
    });

    testWidgets('runs in every ticked session and says so', (tester) async {
      final a = fake('a');
      final b = fake('b');
      final c = fake('c');
      final d = fake('d', live: false);
      await pump(
        tester,
        current: a.target,
        targets: [a.target, b.target, c.target, d.target],
      );

      await tester.tap(find.byKey(const Key('snippetPicker.runOn.up')));
      await tester.pumpAndSettle();

      expect(find.byType(RunOnDialog), findsOneWidget);
      // The session the picker came from is ticked already; a tab that is
      // open but not connected is shown, and cannot be ticked.
      CheckboxListTile tile(String id) =>
          tester.widget<CheckboxListTile>(find.byKey(Key('runOn.$id')));
      expect(tile('a').value, isTrue);
      expect(tile('b').value, isFalse);
      expect(tile('d').onChanged, isNull);

      await tester.tap(find.byKey(const Key('runOn.b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('runOn.confirm')));
      await tester.pumpAndSettle();

      expect(a.sent.join(), 'uptime\r');
      expect(b.sent.join(), 'uptime\r');
      expect(c.sent, isEmpty);
      expect(d.sent, isEmpty);
      expect(find.text('Ran in 2 sessions'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('each session gets its own {{host}}', (tester) async {
      final a = fake('a');
      final b = fake('b');
      await pump(tester, current: a.target, targets: [a.target, b.target]);

      await tester.tap(find.byKey(const Key('snippetPicker.runOn.greet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('runOn.all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('runOn.confirm')));
      await tester.pumpAndSettle();

      // Asked once for both.
      expect(find.byType(SnippetVariablesDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();

      expect(a.sent.join(), 'echo a.example.com hello\r');
      expect(b.sent.join(), 'echo b.example.com hello\r');
      await drain(tester);
    });
  });

  group('on a desktop', () {
    Future<void> asDesktop(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets('it is a dialog, and Enter inserts the highlighted row', (
      tester,
    ) async {
      await asDesktop(() async {
        final a = fake('a');
        await pump(tester, current: a.target);
        expect(find.byType(Dialog), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Second row is "Tail logs" — multi-line, and this shell has not
        // asked for bracketed paste, so the insert is refused rather than
        // half-run. Proves Enter chose Insert and the highlight moved.
        expect(a.sent, isEmpty);
        expect(find.textContaining('Use Run instead'), findsOneWidget);
        await drain(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    testWidgets('Ctrl+Enter runs the highlighted row', (tester) async {
      await asDesktop(() async {
        final a = fake('a');
        await pump(tester, current: a.target);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(a.sent.join(), 'uptime\r');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  });
}
