import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/error/error_logger.dart';
import 'data/mcp_http_server.dart';
import 'data/riverpod_mcp_backend.dart';
import 'domain/approval.dart';
import 'domain/mcp_backend.dart';
import 'domain/mcp_dispatcher.dart';
import 'domain/sshetu_tools.dart';
import 'mcp_audit_controller.dart';
import 'mcp_settings.dart';
import 'mcp_ui_bridge.dart';

enum McpServerState { stopped, starting, running, failed }

@immutable
class McpServerStatus {
  const McpServerStatus(
    this.state, {
    this.port,
    this.error,
    this.fallback = false,
  });

  const McpServerStatus.stopped() : this(McpServerState.stopped);

  final McpServerState state;
  final int? port;
  final String? error;

  /// The preferred port was taken and [port] is another one.
  final bool fallback;

  @override
  bool operator ==(Object other) =>
      other is McpServerStatus &&
      other.state == state &&
      other.port == port &&
      other.error == error &&
      other.fallback == fallback;

  @override
  int get hashCode => Object.hash(state, port, error, fallback);
}

/// Where the window installs its [McpUiBridge].
final mcpUiBridgeSlotProvider = Provider<McpUiBridgeSlot>(
  (ref) => McpUiBridgeSlot(),
);

/// Asks the user through the window's dialog. Tests swap it for a fake that
/// answers at once.
final mcpApproverProvider = Provider<McpApprover>((ref) {
  final slot = ref.watch(mcpUiBridgeSlotProvider);
  return (request) async {
    final bridge = slot.current;
    if (bridge == null) throw const ApprovalUnavailable();
    return bridge.approve(request);
  };
});

final mcpBackendProvider = Provider<McpBackend>(
  (ref) => RiverpodMcpBackend(ref, ref.watch(mcpUiBridgeSlotProvider)),
);

/// Runs the local MCP server while the integration is on, and stops it when
/// it is turned off, its token changes, or the app goes away.
///
/// Watched from the root widget for the whole run, so the server's life
/// follows the setting and nothing else. A token change restarts it, which
/// is also what drops every "approve similar" grant made under the old one.
class McpServerController extends Notifier<McpServerStatus> {
  @override
  McpServerStatus build() {
    final supported = ref.watch(mcpSupportedProvider);
    final settings = ref.watch(mcpSettingsProvider);
    final token = settings.token;
    if (!supported || !settings.enabled || token == null) {
      return const McpServerStatus.stopped();
    }

    final dispatcher = McpDispatcher(
      tools: buildSshetuTools(ref.read(mcpBackendProvider)),
      gate: ApprovalGate(approver: ref.read(mcpApproverProvider)),
      audit: (entry) =>
          unawaited(ref.read(mcpAuditProvider.notifier).add(entry)),
    );
    final server = McpHttpServer(
      dispatcher: dispatcher,
      token: token,
      preferredPort: settings.port,
    );
    ref.onDispose(() => unawaited(server.stop()));
    unawaited(_start(server, dispatcher));
    return const McpServerStatus(McpServerState.starting);
  }

  Future<void> _start(McpHttpServer server, McpDispatcher dispatcher) async {
    try {
      dispatcher.serverVersion = await appVersionForMcp();
      final port = await server.start();
      if (!ref.mounted) {
        await server.stop();
        return;
      }
      state = McpServerStatus(
        McpServerState.running,
        port: port,
        fallback: server.usedFallbackPort,
      );
    } on Object catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'mcp');
      if (ref.mounted) {
        state = McpServerStatus(McpServerState.failed, error: '$error');
      }
    }
  }
}

final mcpServerControllerProvider =
    NotifierProvider<McpServerController, McpServerStatus>(
      McpServerController.new,
    );

/// The app's version, for `serverInfo`. Read once; a failure is not worth
/// failing the server over.
Future<String> appVersionForMcp() async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } on Object {
    return '1.0.0';
  }
}
