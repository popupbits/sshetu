import '../../core/terminal/terminal_session.dart';
import '../hosts/domain/ssh_host.dart';
import '../tunnels/domain/tunnel.dart';
import 'domain/approval.dart';

/// What the MCP server needs a window for: asking the user, and the two
/// actions whose existing flows raise dialogs of their own (a host key to
/// trust, a password to type).
///
/// Implemented by `McpUiHost`, which sits in the widget tree for the life of
/// the app and installs itself in [McpUiBridgeSlot].
abstract interface class McpUiBridge {
  /// Shows the approval dialog for [request]; resolves when the user
  /// answers or the request expires.
  Future<ApprovalDecision> approve(ApprovalRequest request);

  /// Opens a tab to [host] through `connectToHost`, exactly as a tap on the
  /// host would. Null when nothing was opened.
  Future<TerminalSession?> openSession(SshHost host);

  /// Starts [tunnel] through `startTunnel`, exactly as the Tunnels screen
  /// does.
  Future<void> startTunnel(Tunnel tunnel);
}

/// Where the bridge is installed. A plain holder rather than state: nothing
/// rebuilds when a window comes or goes, the server just asks at call time.
class McpUiBridgeSlot {
  McpUiBridge? current;
}
