import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/terminal/tmux_commands.dart';
import 'package:sshetu/features/sessions/widgets/running_sessions_view.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// "Sessions on this server": this device's and other devices' sessions,
/// with Attach and End.
void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  TmuxListing listing() => TmuxListing(
    tmuxAvailable: true,
    sessions: [
      TmuxSessionInfo(
        name: 'sshetu-mine01-aaaaaaaa',
        created: now.subtract(const Duration(hours: 2)),
        attachedClients: 0,
        lastActivity: now.subtract(const Duration(minutes: 5)),
        command: 'bash',
      ),
      TmuxSessionInfo(
        name: 'sshetu-desk99-bbbbbbbb',
        created: now.subtract(const Duration(days: 1)),
        attachedClients: 1,
        lastActivity: now.subtract(const Duration(minutes: 1)),
        command: 'vim',
      ),
      TmuxSessionInfo(
        name: 'sshetu-h1-0',
        created: now.subtract(const Duration(days: 3)),
        attachedClients: 0,
      ),
    ],
  );

  Future<List<String?>> pump(
    WidgetTester tester, {
    required Size size,
    Future<TmuxListing> Function()? load,
    List<String>? ended,
    Set<String> openHere = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final popped = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                // The real presentation: a sheet on a phone, a dialog on a
                // desktop.
                onPressed: () async {
                  popped.add(
                    await showRunningSessionsView(
                      context,
                      RunningSessionsView(
                        hostLabel: 'web-1',
                        deviceId: 'mine01',
                        load: load ?? () async => listing(),
                        end: (name) async => ended?.add(name),
                        isOpenHere: openHere.contains,
                        clock: () => now,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  for (final (name, size) in [
    ('phone', const Size(360, 780)),
    ('desktop', const Size(1280, 900)),
  ]) {
    testWidgets('says whose each session is, at $name width', (tester) async {
      await pump(tester, size: size, openHere: {'sshetu-mine01-aaaaaaaa'});

      expect(find.text('Sessions on web-1'), findsOneWidget);
      // The point of the screen, said in so many words.
      expect(find.textContaining('carry on from your phone'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
      expect(find.text('Another device (desk99)'), findsOneWidget);
      expect(find.text('An earlier SSHetu version'), findsOneWidget);
      expect(find.text('Open here'), findsOneWidget);
      expect(find.text('Attached elsewhere'), findsOneWidget);
      expect(
        find.text('started 2h ago · active 5m ago · running bash'),
        findsOneWidget,
      );
      // Sharing a session attached elsewhere is allowed, and said.
      expect(find.textContaining('shares it'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Attach closes with the session to open', (tester) async {
    final popped = await pump(tester, size: const Size(360, 780));
    await tester.tap(
      find.byKey(
        const ValueKey('runningSession.attach.sshetu-desk99-bbbbbbbb'),
      ),
    );
    await tester.pumpAndSettle();
    expect(popped, ['sshetu-desk99-bbbbbbbb']);
  });

  testWidgets('End asks first, then ends and refreshes', (tester) async {
    final ended = <String>[];
    var loads = 0;
    await pump(
      tester,
      size: const Size(1280, 900),
      ended: ended,
      load: () async {
        loads++;
        return listing();
      },
    );
    expect(loads, 1);

    final end = find.byKey(
      const ValueKey('runningSession.end.sshetu-desk99-bbbbbbbb'),
    );
    await tester.tap(end);
    await tester.pumpAndSettle();
    expect(find.text('End this session?'), findsOneWidget);
    // Cancelled: nothing happens.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(ended, isEmpty);

    await tester.tap(end);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'End'));
    await tester.pumpAndSettle();
    expect(ended, ['sshetu-desk99-bbbbbbbb']);
    expect(loads, 2);
  });

  testWidgets('no tmux, none running, and a failure each say so', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(360, 780),
      load: () async => const TmuxListing(tmuxAvailable: false, sessions: []),
    );
    expect(find.textContaining('tmux is not installed'), findsOneWidget);
  });

  testWidgets('an empty server explains where sessions come from', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(360, 780),
      load: () async => const TmuxListing(tmuxAvailable: true, sessions: []),
    );
    expect(
      find.text('No SSHetu sessions are running on this server'),
      findsOneWidget,
    );
  });

  testWidgets('a failed listing offers to try again', (tester) async {
    var calls = 0;
    await pump(
      tester,
      size: const Size(360, 780),
      load: () async {
        calls++;
        throw StateError('channel refused');
      },
    );
    expect(
      find.text('Could not list the sessions on this server'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Refresh'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
