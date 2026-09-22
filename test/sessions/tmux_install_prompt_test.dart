import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/terminal/tmux_install.dart';
import 'package:sshetu/features/sessions/tmux_install_assistant.dart';
import 'package:sshetu/features/sessions/widgets/tmux_install_prompt.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The install offer drawn over a tab, at a phone width and a desktop one.
void main() {
  late List<String> pressed;

  Future<void> pump(
    WidgetTester tester,
    Size size,
    TmuxInstallStage stage, {
    bool settle = true,
  }) async {
    pressed = [];
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: Column(
            children: [
              TmuxInstallPrompt(
                stage: stage,
                hostLabel: 'build-box',
                onInstall: () => pressed.add('install'),
                onInstallWithUpdate: () => pressed.add('update'),
                onNotNow: () => pressed.add('notNow'),
                onNever: () => pressed.add('never'),
                onRestart: () => pressed.add('restart'),
                onDismiss: () => pressed.add('dismiss'),
              ),
              const Expanded(child: Placeholder()),
            ],
          ),
        ),
      ),
    );
    settle ? await tester.pumpAndSettle() : await tester.pump();
  }

  const root = RunInstall(
    manager: PackageManager.aptGet,
    elevation: Elevation.none,
  );
  const typed = TypeInstallInTerminal(manager: PackageManager.dnf);

  for (final (name, size) in [
    ('phone', const Size(360, 800)),
    ('desktop', const Size(1280, 900)),
  ]) {
    group('at $name width', () {
      testWidgets('the offer names the host and shows the exact command', (
        tester,
      ) async {
        await pump(tester, size, const TmuxInstallOffered(root));
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            "tmux isn't installed on build-box, so this session won't survive "
            'a dropped connection. Install it?',
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('tmuxInstall.command')),
            matching: find.text(root.command),
          ),
          findsOneWidget,
        );
        for (final (key, action) in [
          ('tmuxInstall.install', 'install'),
          ('tmuxInstall.notNow', 'notNow'),
          ('tmuxInstall.never', 'never'),
        ]) {
          await tester.tap(find.byKey(Key(key)));
          expect(pressed.last, action);
        }
      });

      testWidgets('sudo with a password: says the terminal will ask', (
        tester,
      ) async {
        await pump(tester, size, const TmuxInstallOffered(typed));
        expect(tester.takeException(), isNull);
        expect(find.text('sudo dnf install -y tmux'), findsOneWidget);
        expect(find.textContaining('SSHetu never sees it'), findsOneWidget);
        expect(find.text('Run in terminal'), findsOneWidget);
      });

      testWidgets('typed: tells the user to enter the password there', (
        tester,
      ) async {
        await pump(tester, size, const TmuxInstallTyped(typed));
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('Enter your sudo password in the terminal'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('tmuxInstall.restart')));
        expect(pressed, ['restart']);
      });

      testWidgets('running shows the command and no buttons', (tester) async {
        await pump(tester, size, const TmuxInstallRunning(root), settle: false);
        expect(tester.takeException(), isNull);
        expect(find.text('Installing tmux on build-box…'), findsOneWidget);
        expect(find.byType(TextButton), findsNothing);
      });

      testWidgets('success says what a restart closes', (tester) async {
        await pump(tester, size, const TmuxInstallSucceeded());
        expect(tester.takeException(), isNull);
        expect(find.textContaining('anything running in it stops'), findsOne);
        await tester.tap(find.byKey(const Key('tmuxInstall.restart')));
        await tester.tap(find.byKey(const Key('tmuxInstall.later')));
        expect(pressed, ['restart', 'dismiss']);
      });

      testWidgets('a failure shows the end of its output', (tester) async {
        final output = [for (var i = 1; i <= 30; i++) 'line $i'].join('\n');
        await pump(tester, size, TmuxInstallFailed(root, output));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('line 30'), findsOneWidget);
        expect(find.textContaining('line 1\n'), findsNothing);
        expect(find.byKey(const Key('tmuxInstall.update')), findsNothing);
      });

      testWidgets('stale lists: offers update, showing that command', (
        tester,
      ) async {
        const retry = RunInstall(
          manager: PackageManager.aptGet,
          elevation: Elevation.none,
          withUpdate: true,
        );
        await pump(
          tester,
          size,
          const TmuxInstallFailed(
            root,
            'E: Unable to locate package tmux',
            retry: retry,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(retry.command), findsOneWidget);
        await tester.tap(find.byKey(const Key('tmuxInstall.update')));
        expect(pressed, ['update']);
      });

      testWidgets('nothing to run: explains, and offers no Install', (
        tester,
      ) async {
        await pump(
          tester,
          size,
          const TmuxInstallOffered(
            InstallUnavailable(InstallUnavailableReason.noPrivilege),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('has no sudo'), findsOneWidget);
        expect(find.byKey(const Key('tmuxInstall.install')), findsNothing);
        expect(find.byKey(const Key('tmuxInstall.never')), findsOneWidget);
      });
    });
  }

  testWidgets('draws nothing while idle, detecting or dismissed', (
    tester,
  ) async {
    for (final stage in const [
      TmuxInstallIdle(),
      TmuxInstallDetecting(),
      TmuxInstallDismissed(),
    ]) {
      await pump(tester, const Size(360, 800), stage);
      expect(find.byKey(const Key('tmuxInstall.banner')), findsNothing);
    }
  });
}
