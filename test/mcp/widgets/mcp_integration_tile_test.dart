import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/mcp/domain/audit_entry.dart';
import 'package:sshetu/features/mcp/mcp_audit_controller.dart';
import 'package:sshetu/features/mcp/mcp_server_controller.dart';
import 'package:sshetu/features/mcp/mcp_settings.dart';
import 'package:sshetu/features/mcp/widgets/mcp_integration_tile.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// Reports a fixed status and opens no socket.
class _FixedServer extends McpServerController {
  _FixedServer(this.status);

  final McpServerStatus status;

  @override
  McpServerStatus build() {
    ref.watch(mcpSettingsProvider);
    return status;
  }
}

void main() {
  late SharedPreferences prefs;
  late List<String> clipboard;

  setUp(() async {
    clipboard = [];
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required double width,
    Map<String, Object> stored = const {},
    McpServerStatus status = const McpServerStatus(
      McpServerState.running,
      port: 47832,
    ),
  }) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(stored);
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mcpServerControllerProvider.overrideWith(() => _FixedServer(status)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: SingleChildScrollView(child: McpIntegrationTile()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  const token = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';

  for (final width in [360.0, 1280.0]) {
    group('at ${width.toInt()}px', () {
      testWidgets('off: only the switch and the activity row', (tester) async {
        await pump(tester, width: width);
        expect(tester.takeException(), isNull);
        expect(find.text('Let AI assistants use SSHetu'), findsOneWidget);
        expect(find.byKey(const Key('mcp.token')), findsNothing);
        expect(find.text('No calls yet'), findsOneWidget);
      });

      testWidgets('turning it on makes a token and shows the setup', (
        tester,
      ) async {
        final container = await pump(tester, width: width);
        await tester.tap(find.byKey(const Key('mcp.enabled')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final token = container.read(mcpSettingsProvider).token!;
        expect(prefs.getBool('mcp.enabled'), isTrue);
        expect(
          find.text('Listening on http://127.0.0.1:47832/mcp'),
          findsOneWidget,
        );
        // Masked until asked for — in the snippets as well.
        expect(find.textContaining(token), findsNothing);
        expect(
          find.textContaining('claude mcp add --transport http sshetu'),
          findsOneWidget,
        );
      });

      testWidgets('reveal, copy and the snippets carry the real token', (
        tester,
      ) async {
        await pump(
          tester,
          width: width,
          stored: {'mcp.enabled': true, 'mcp.token': token},
        );
        expect(find.textContaining(token), findsNothing);
        await tester.tap(find.byKey(const Key('mcp.token.reveal')));
        await tester.pumpAndSettle();
        expect(find.text(token), findsOneWidget);
        expect(
          find.text(
            'claude mcp add --transport http sshetu '
            'http://127.0.0.1:47832/mcp '
            '--header "Authorization: Bearer $token"',
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('mcp.token.copy')));
        await tester.pumpAndSettle();
        expect(clipboard.last, token);

        await tester.ensureVisible(find.byKey(const Key('mcp.setup.json')));
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('mcp.setup.json')),
            matching: find.byType(IconButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(clipboard.last, contains('"Authorization": "Bearer $token"'));
        expect(clipboard.last, contains('"url": "http://127.0.0.1:47832/mcp"'));
      });

      testWidgets('regenerate asks first, then replaces the token', (
        tester,
      ) async {
        final container = await pump(
          tester,
          width: width,
          stored: {'mcp.enabled': true, 'mcp.token': token},
        );
        await tester.tap(find.byKey(const Key('mcp.token.regenerate')));
        await tester.pumpAndSettle();
        expect(find.text('Regenerate the access token?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(container.read(mcpSettingsProvider).token, token);

        await tester.tap(find.byKey(const Key('mcp.token.regenerate')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Regenerate token'),
          ),
        );
        await tester.pumpAndSettle();
        expect(container.read(mcpSettingsProvider).token, isNot(token));
      });

      testWidgets('a fallback port and a failure are explained', (
        tester,
      ) async {
        await pump(
          tester,
          width: width,
          stored: {'mcp.enabled': true, 'mcp.token': token},
          status: const McpServerStatus(
            McpServerState.running,
            port: 50001,
            fallback: true,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Port 47832 was busy'), findsOneWidget);
        expect(find.textContaining('127.0.0.1:50001/mcp'), findsWidgets);
      });

      testWidgets('the activity list, and clearing it', (tester) async {
        final container = await pump(tester, width: width);
        await container
            .read(mcpAuditProvider.notifier)
            .add(
              AuditEntry(
                time: DateTime(2026, 9, 22, 10, 30),
                client: 'claude-code',
                tool: 'run_command',
                target: 'web-1 — deploy@10.0.0.4:22 (session s-1)',
                decision: AuditDecision.denied,
              ),
            );
        await container
            .read(mcpAuditProvider.notifier)
            .add(
              AuditEntry(
                time: DateTime(2026, 9, 22, 10, 31),
                client: 'claude-code',
                tool: 'list_hosts',
                decision: AuditDecision.read,
                resultBytes: 2048,
              ),
            );
        await tester.pumpAndSettle();
        expect(find.text('2 calls recorded'), findsOneWidget);

        await tester.tap(find.byKey(const Key('mcp.activity')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('MCP activity'), findsOneWidget);
        expect(find.text('run_command · claude-code'), findsOneWidget);
        expect(find.textContaining('Denied'), findsOneWidget);
        expect(find.textContaining('returned'), findsOneWidget);

        await tester.tap(find.byKey(const Key('mcp.activity.clear')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Clear log'),
          ),
        );
        await tester.pumpAndSettle();
        expect(container.read(mcpAuditProvider), isEmpty);
        expect(find.textContaining('No calls yet.'), findsOneWidget);
      });
    });
  }
}
