import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/router.dart';
import '../../../core/terminal/terminal_session.dart';
import '../../hosts/domain/ssh_host.dart';
import '../../sessions/connect.dart';
import '../../tunnels/domain/tunnel.dart';
import '../../tunnels/tunnel_connect.dart' as tunnels;
import '../domain/approval.dart';
import '../mcp_server_controller.dart';
import '../mcp_ui_bridge.dart';
import 'mcp_approval_dialog.dart';

/// The window's side of the MCP integration: shows approval dialogs, and
/// runs the two actions that go through flows with dialogs of their own.
///
/// Sits in the app's builder for the whole run and installs itself as the
/// [McpUiBridge]. Dialogs open over the root navigator, so they appear
/// whichever screen or workspace tab is showing — and even when the window
/// is not focused; the call waits for them (up to the gate's timeout).
/// One dialog at a time: a second request waits for the first answer.
class McpUiHost extends ConsumerStatefulWidget {
  const McpUiHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<McpUiHost> createState() => _McpUiHostState();
}

class _McpUiHostState extends ConsumerState<McpUiHost> implements McpUiBridge {
  late final McpUiBridgeSlot _slot;
  Future<void> _queue = Future.value();

  @override
  void initState() {
    super.initState();
    _slot = ref.read(mcpUiBridgeSlotProvider)..current = this;
  }

  @override
  void dispose() {
    if (identical(_slot.current, this)) _slot.current = null;
    super.dispose();
  }

  BuildContext get _dialogContext =>
      rootNavigatorKey.currentContext ?? (throw const ApprovalUnavailable());

  @override
  Future<ApprovalDecision> approve(ApprovalRequest request) {
    final answer = Completer<ApprovalDecision>();
    _queue = _queue.then((_) async {
      if (request.isExpired || !mounted) {
        answer.complete(ApprovalDecision.deny);
        return;
      }
      try {
        answer.complete(await McpApprovalDialog.show(_dialogContext, request));
      } on Object catch (error) {
        answer.completeError(error);
      }
    });
    return answer.future;
  }

  @override
  Future<TerminalSession?> openSession(SshHost host) async {
    final context = _dialogContext;
    if (!context.mounted) return null;
    // navigate: false — the assistant asked, not the user; the new tab is
    // selected in the workspace but the screen is not taken away from them.
    return connectToHost(context, ref, host, navigate: false);
  }

  @override
  Future<void> startTunnel(Tunnel tunnel) async {
    final context = _dialogContext;
    if (!context.mounted) return;
    await tunnels.startTunnel(context, ref, tunnel);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
