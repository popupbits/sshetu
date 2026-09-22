import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/terminal_find_request.dart';
import 'package:sshetu/features/sessions/widgets/terminal_find_bar.dart';
import 'package:sshetu/features/sessions/widgets/terminal_pane.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:xterm2/xterm.dart';

/// The find bar, driven the way a person drives it: the shortcut opens it,
/// typing counts, Enter and Shift+Enter move, Esc closes and hands the
/// keyboard back to the shell.
void main() {
  /// A session that is never started: the pane only needs its terminal, and
  /// the connection is not dialled until `start`.
  TerminalSession buildSession() => TerminalSession(
    id: 'host-1',
    title: 'test',
    hostId: 'host',
    connection: SshConnection(
      target: const SshTarget(hostname: 'example.invalid', username: 'me'),
      verifierFactory: (_, _) => throw UnimplementedError(),
    ),
  );

  late ProviderContainer container;

  Future<TerminalSession> pumpPane(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = buildSession();
    container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: TerminalPane(session: session)),
        ),
      ),
    );
    session.terminal.write(
      'deploy started\r\nerror: disk full\r\nretrying\r\n'
      'ERROR: still full\r\nerror: giving up\r\n',
    );
    await tester.pump();
    return session;
  }

  /// Tears the tree down while the platform override is still in place, so
  /// nothing that reads it during dispose sees a different platform.
  Future<void> finish(WidgetTester tester, TerminalSession session) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    session.dispose();
  }

  Future<void> asDesktop(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> pressFindShortcut(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // One frame to build the bar, one for its post-frame focus request.
    await tester.pump();
    await tester.pump();
  }

  String status(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('terminal-find-status')))
      .data!;

  TerminalController controllerOf(WidgetTester tester) =>
      tester.widget<TerminalView>(find.byType(TerminalView)).controller!;

  testWidgets('Ctrl+Shift+F opens the bar with the field focused', (
    tester,
  ) async {
    await asDesktop(() async {
      final session = await pumpPane(tester);
      expect(find.byType(TerminalFindBar), findsNothing);

      await pressFindShortcut(tester);

      expect(find.byType(TerminalFindBar), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('terminal-find-field')),
      );
      expect(field.focusNode!.hasFocus, isTrue);

      // Asking again while it is open keeps it open, and focused.
      await pressFindShortcut(tester);
      expect(find.byType(TerminalFindBar), findsOneWidget);
      expect(field.focusNode!.hasFocus, isTrue);

      // Typing without clicking lands in the field, not in the shell.
      final sent = <String>[];
      session.terminal.onOutput = sent.add;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(sent, isEmpty);
      await finish(tester, session);
    });
  });

  testWidgets('plain Ctrl+F still reaches the shell', (tester) async {
    await asDesktop(() async {
      final session = await pumpPane(tester);
      final sent = <String>[];
      session.terminal.onOutput = sent.add;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(find.byType(TerminalFindBar), findsNothing);
      expect(sent.join(), '\x06', reason: 'Ctrl+F is ^F, forward-char');
      await finish(tester, session);
    });
  });

  testWidgets('typing counts matches and highlights them', (tester) async {
    await asDesktop(() async {
      final session = await pumpPane(tester);
      await pressFindShortcut(tester);

      await tester.enterText(
        find.byKey(const ValueKey('terminal-find-field')),
        'error',
      );
      await tester.pump();

      expect(status(tester), '1 of 3');
      expect(controllerOf(tester).searchHighlights, hasLength(3));

      await tester.enterText(
        find.byKey(const ValueKey('terminal-find-field')),
        'nothing like this',
      );
      await tester.pump();
      expect(status(tester), 'No matches');
      await finish(tester, session);
    });
  });

  testWidgets('Enter goes back, Shift+Enter comes forward', (tester) async {
    await asDesktop(() async {
      final session = await pumpPane(tester);
      await pressFindShortcut(tester);
      await tester.enterText(
        find.byKey(const ValueKey('terminal-find-field')),
        'error',
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(status(tester), '2 of 3');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(status(tester), '3 of 3');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(status(tester), '2 of 3');
      await finish(tester, session);
    });
  });

  testWidgets('the case and regex toggles re-run the search', (tester) async {
    await asDesktop(() async {
      final session = await pumpPane(tester);
      await pressFindShortcut(tester);
      await tester.enterText(
        find.byKey(const ValueKey('terminal-find-field')),
        'error',
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Match case'));
      await tester.pump();
      expect(status(tester), '1 of 2');

      await tester.tap(find.byTooltip('Regular expression'));
      await tester.enterText(
        find.byKey(const ValueKey('terminal-find-field')),
        'error: (disk|giving)',
      );
      await tester.pump();
      expect(status(tester), '1 of 2');

      await tester.enterText(
        find.byKey(const ValueKey('terminal-find-field')),
        'error: (',
      );
      await tester.pump();
      expect(status(tester), 'Invalid pattern');
      await finish(tester, session);
    });
  });

  testWidgets('Esc closes the bar, clears highlights, refocuses the terminal', (
    tester,
  ) async {
    await asDesktop(() async {
      final session = await pumpPane(tester);
      await pressFindShortcut(tester);
      await tester.enterText(
        find.byKey(const ValueKey('terminal-find-field')),
        'error',
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(TerminalFindBar), findsNothing);
      expect(controllerOf(tester).searchHighlights, isEmpty);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'terminal');
      await finish(tester, session);
    });
  });

  testWidgets('a request for this session opens the bar', (tester) async {
    await asDesktop(() async {
      final session = await pumpPane(tester);

      container.read(terminalFindRequestProvider.notifier).request('other');
      await tester.pump();
      expect(
        find.byType(TerminalFindBar),
        findsNothing,
        reason: 'a request for another session is not ours',
      );

      container.read(terminalFindRequestProvider.notifier).request(session.id);
      await tester.pump();
      expect(find.byType(TerminalFindBar), findsOneWidget);
      await finish(tester, session);
    });
  });

  testWidgets('the close button closes it too', (tester) async {
    await asDesktop(() async {
      final session = await pumpPane(tester);
      await pressFindShortcut(tester);
      await tester.tap(find.byTooltip('Close (Esc)'));
      await tester.pump();
      expect(find.byType(TerminalFindBar), findsNothing);
      await finish(tester, session);
    });
  });
}
