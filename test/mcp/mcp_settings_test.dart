import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/features/mcp/data/mcp_http_server.dart';
import 'package:sshetu/features/mcp/domain/audit_entry.dart';
import 'package:sshetu/features/mcp/mcp_audit_controller.dart';
import 'package:sshetu/features/mcp/mcp_server_controller.dart';
import 'package:sshetu/features/mcp/mcp_settings.dart';

void main() {
  Future<(ProviderContainer, SharedPreferences)> containerWith(
    Map<String, Object> stored,
  ) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return (container, prefs);
  }

  group('settings', () {
    test('off by default, with no token and the default port', () async {
      final (container, _) = await containerWith({});
      final settings = container.read(mcpSettingsProvider);
      expect(settings.enabled, isFalse);
      expect(settings.token, isNull);
      expect(settings.port, kDefaultMcpPort);
      expect(
        container.read(mcpServerControllerProvider).state,
        McpServerState.stopped,
      );
    });

    test('turning it on makes a token once, and persists both', () async {
      final (container, prefs) = await containerWith({});
      final controller = container.read(mcpSettingsProvider.notifier);
      // Nothing here reads the server controller, so no socket opens: this
      // is about the settings alone.
      await controller.setEnabled(true);
      final token = container.read(mcpSettingsProvider).token;
      expect(token, hasLength(43));
      expect(prefs.getBool('mcp.enabled'), isTrue);
      expect(prefs.getString('mcp.token'), token);

      await controller.setEnabled(false);
      await controller.setEnabled(true);
      expect(container.read(mcpSettingsProvider).token, token);
    });

    test('regenerating replaces the token', () async {
      final (container, prefs) = await containerWith({'mcp.token': 'old'});
      await container.read(mcpSettingsProvider.notifier).regenerateToken();
      final token = container.read(mcpSettingsProvider).token;
      expect(token, isNot('old'));
      expect(prefs.getString('mcp.token'), token);
    });

    test('a stored value of the wrong type or range reads as unset', () async {
      final (container, _) = await containerWith({
        'mcp.enabled': 'yes',
        'mcp.port': 70000,
      });
      final settings = container.read(mcpSettingsProvider);
      expect(settings.enabled, isFalse);
      expect(settings.port, kDefaultMcpPort);
    });
  });

  group('activity log', () {
    AuditEntry entry(String tool) => AuditEntry(
      time: DateTime.utc(2026, 9, 22),
      client: 'claude-code',
      tool: tool,
      decision: AuditDecision.approved,
    );

    test('adds newest first, persists, and survives a corrupt line', () async {
      final (container, prefs) = await containerWith({});
      final log = container.read(mcpAuditProvider.notifier);
      await log.add(entry('a'));
      await log.add(entry('b'));
      expect(container.read(mcpAuditProvider).map((e) => e.tool), ['b', 'a']);
      final stored = prefs.getStringList('mcp.audit')!;
      expect(stored, hasLength(2));

      final (reopened, _) = await containerWith({
        'mcp.audit': ['{not json', ...stored],
      });
      expect(reopened.read(mcpAuditProvider).map((e) => e.tool), ['b', 'a']);
    });

    test('is capped', () async {
      final (container, prefs) = await containerWith({});
      final log = container.read(mcpAuditProvider.notifier);
      for (var i = 0; i < kMcpAuditCap + 3; i++) {
        await log.add(entry('t$i'));
      }
      expect(container.read(mcpAuditProvider), hasLength(kMcpAuditCap));
      expect(prefs.getStringList('mcp.audit'), hasLength(kMcpAuditCap));
    });

    test('clears', () async {
      final (container, prefs) = await containerWith({});
      final log = container.read(mcpAuditProvider.notifier);
      await log.add(entry('a'));
      await log.clear();
      expect(container.read(mcpAuditProvider), isEmpty);
      expect(prefs.getStringList('mcp.audit'), isNull);
    });
  });
}
