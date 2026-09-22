import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/sessions/reconnect_triggers.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/widgets/terminal_workspace.dart';
import 'package:sshetu/l10n/app_localizations.dart';
import 'package:xterm2/xterm.dart';

import '../support/fake_shell.dart';
import 'reconnect_triggers_test.dart' show FakeTriggers;

/// Output reaching one tab must cost that tab's terminal a repaint and
/// nothing more: no widget in the workspace — the tab strip, the pane
/// header, the status bar, the other nineteen tabs — rebuilds because bytes
/// arrived. Rebuilding chrome per output chunk is the classic way a terminal
/// app turns `cat bigfile` into a frozen window.
///
/// Counted with the framework's own hooks: [debugOnRebuildDirtyWidget] for
/// every element rebuilt, [debugOnProfilePaint] for every render object
/// painted through its parent.
void main() {
  const tabCount = 20;
  late ProviderContainer container;
  late SessionManager manager;
  late List<TerminalSession> sessions;
  late List<FakeLauncher> launchers;

  Future<void> pumpWorkspace(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final triggers = FakeTriggers();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        reconnectTriggersProvider.overrideWithValue(triggers),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(triggers.dispose);
    manager = container.read(sessionManagerProvider.notifier);

    launchers = [for (var i = 0; i < tabCount; i++) FakeLauncher()];
    sessions = [
      for (var i = 0; i < tabCount; i++)
        TerminalSession(
          id: 's$i',
          title: 'host-$i',
          hostId: 'h$i',
          connection: SshConnection(
            target: const SshTarget(
              hostname: 'example.invalid',
              username: 'me',
            ),
            verifierFactory: (_, _) => throw UnimplementedError(),
          ),
          launcher: launchers[i],
          probe: () async => true,
        ),
    ];
    for (final s in sessions) {
      manager.adopt(s);
    }
    await tester.runAsync(() async {
      for (final s in sessions) {
        await s.start();
      }
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(body: TerminalWorkspace()),
        ),
      ),
    );
    await tester.pump();
    // Past the coalescer's idle threshold, so every session starts quiet.
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tearDownWorkspace(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (final s in sessions) {
      manager.close(s.id);
    }
    await tester.pump(const Duration(seconds: 3));
  }

  /// Counts rebuilt elements and painted render objects, by type, while
  /// [body] runs.
  Future<({Map<String, int> builds, Map<String, int> paints})> count(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final builds = <String, int>{};
    final paints = <String, int>{};
    debugOnRebuildDirtyWidget = (element, _) {
      final name = element.widget.runtimeType.toString();
      builds[name] = (builds[name] ?? 0) + 1;
    };
    debugOnProfilePaint = (renderObject) {
      final name = renderObject.runtimeType.toString();
      paints[name] = (paints[name] ?? 0) + 1;
    };
    try {
      await body();
    } finally {
      debugOnRebuildDirtyWidget = null;
      debugOnProfilePaint = null;
    }
    return (builds: builds, paints: paints);
  }

  /// A megabyte of build-log-ish output into [index]'s shell, in 16 KiB
  /// reads, with a 16 ms frame after every four — about 4 MB/s.
  Future<int> flood(WidgetTester tester, int index) async {
    final line = utf8.encode(
      '\x1b[32m  ok\x1b[0m compiled some/module/path.dart in 12ms\r\n',
    );
    final chunk = <int>[];
    while (chunk.length < 16 * 1024) {
      chunk.addAll(line);
    }
    final text = utf8.decode(chunk);
    var framesAsked = 0;
    for (var i = 0; i < 64; i++) {
      launchers[index].shells.last.emit(text);
      if (i % 4 == 3) {
        // Let the stream events land without drawing a frame, then see
        // whether anything asked for one.
        for (var k = 0; k < 8; k++) {
          await Future<void>.value();
        }
        if (tester.binding.hasScheduledFrame) framesAsked++;
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    await tester.pump(const Duration(milliseconds: 50));
    return framesAsked;
  }

  testWidgets('a flood into a background tab rebuilds and repaints nothing', (
    tester,
  ) async {
    await pumpWorkspace(tester);
    expect(manager.activeId, 's${tabCount - 1}');

    late int framesAsked;
    final counted = await count(tester, () async {
      framesAsked = await flood(tester, 0);
    });
    // ignore: avoid_print
    print(
      'background flood: ${counted.builds.length} widget types rebuilt '
      '${counted.builds}, paints ${counted.paints}, $framesAsked frames '
      'asked for',
    );

    expect(counted.builds, isEmpty, reason: 'nothing on screen changed');
    expect(framesAsked, 0, reason: 'nothing on screen changed');
    // And the output really arrived.
    expect(
      sessions[0].terminal.buffer.getText(),
      contains('compiled some/module/path.dart'),
    );
    await tearDownWorkspace(tester);
  });

  testWidgets('a flood into the visible tab repaints only its terminal', (
    tester,
  ) async {
    await pumpWorkspace(tester);
    final visible = tabCount - 1;

    late int framesAsked;
    final counted = await count(tester, () async {
      framesAsked = await flood(tester, visible);
    });
    // ignore: avoid_print
    print(
      'visible flood (1 MiB): rebuilt ${counted.builds}, paints '
      '${counted.paints}, $framesAsked frames asked for',
    );

    expect(
      counted.builds,
      isEmpty,
      reason:
          'output must not rebuild any widget — the tab strip, pane header '
          'and status bar included; the terminal repaints itself',
    );
    // Only the terminal's own layer repaints. It is a repaint boundary, so
    // repainting it alone never goes through a parent's paintChild — which is
    // what the paint hook sees. Before the pane gave it tight constraints,
    // its per-output relayout climbed to the screen's root and every output
    // frame repainted ~100 render objects of chrome (tab strip text, icon
    // buttons, the pane's column) along with it.
    expect(
      counted.paints,
      isEmpty,
      reason: 'output must repaint the terminal layer and nothing around it',
    );
    // At most one frame per batch of reads: the coalescer and the render
    // object between them never ask for more than the frames that ran.
    expect(framesAsked, inInclusiveRange(1, 16));
    expect(
      sessions[visible].terminal.buffer.getText(),
      contains('compiled some/module/path.dart'),
    );
    await tearDownWorkspace(tester);
  });

  testWidgets('switching tabs builds one terminal, not twenty', (tester) async {
    await pumpWorkspace(tester);

    final counted = await count(tester, () async {
      manager.select('s3');
      await tester.pump();
    });
    // ignore: avoid_print
    print('tab switch: rebuilt ${counted.builds}');

    expect(find.byType(TerminalView), findsOneWidget);
    expect(counted.builds['TerminalView'] ?? 0, lessThanOrEqualTo(1));
    await tearDownWorkspace(tester);
  });
}
