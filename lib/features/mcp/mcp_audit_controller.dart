import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import 'domain/audit_entry.dart';

const _keyAudit = 'mcp.audit';

/// The MCP activity log, newest first, kept in shared_preferences and capped
/// at [kMcpAuditCap] entries. Settings → Integrations → Activity shows it.
class McpAuditController extends Notifier<List<AuditEntry>> {
  @override
  List<AuditEntry> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    try {
      final stored = prefs.getStringList(_keyAudit) ?? const [];
      return [for (final line in stored.take(kMcpAuditCap)) ?_decode(line)];
    } on Object {
      // Another type under the key: start a fresh log rather than fail.
      return const [];
    }
  }

  static AuditEntry? _decode(String line) {
    try {
      return AuditEntry.fromJson(jsonDecode(line));
    } on FormatException {
      return null;
    }
  }

  Future<void> add(AuditEntry entry) async {
    state = prependCapped(state, entry);
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(sharedPreferencesProvider).remove(_keyAudit);
  }

  Future<void> _save() => ref.read(sharedPreferencesProvider).setStringList(
    _keyAudit,
    [for (final entry in state) jsonEncode(entry.toJson())],
  );
}

final mcpAuditProvider = NotifierProvider<McpAuditController, List<AuditEntry>>(
  McpAuditController.new,
);
