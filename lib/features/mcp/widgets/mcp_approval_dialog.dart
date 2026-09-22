import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/approval.dart';

/// Asks the user whether an MCP client may do one thing.
///
/// Names the client (as it named itself), the action, the exact session,
/// host or tunnel, and the exact text, keystrokes or paths — with control
/// characters shown, never interpreted. Deny has the focus, so an Enter
/// pressed while typing elsewhere cannot approve anything; dismissing the
/// dialog any other way is a denial. It closes itself when the request
/// expires.
class McpApprovalDialog extends StatefulWidget {
  const McpApprovalDialog({
    required this.request,
    this.rememberMinutes = 10,
    super.key,
  });

  final ApprovalRequest request;
  final int rememberMinutes;

  /// Shows the dialog over [context]; a denial for anything but Approve.
  static Future<ApprovalDecision> show(
    BuildContext context,
    ApprovalRequest request,
  ) async {
    final decision = await showDialog<ApprovalDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => McpApprovalDialog(request: request),
    );
    return decision ?? ApprovalDecision.deny;
  }

  @override
  State<McpApprovalDialog> createState() => _McpApprovalDialogState();
}

class _McpApprovalDialogState extends State<McpApprovalDialog> {
  bool _remember = false;

  /// Set once this dialog has popped itself, so an expiry arriving during
  /// the exit animation does not pop the route underneath.
  bool _closed = false;

  void _close([ApprovalDecision? decision]) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(decision);
  }

  @override
  void initState() {
    super.initState();
    unawaited(widget.request.expired.then((_) => _close()));
  }

  String _action(AppLocalizations l10n) => switch (widget.request.toolName) {
    'run_command' => l10n.mcpActionRunCommand,
    'send_input' => l10n.mcpActionSendInput,
    'open_session' => l10n.mcpActionOpenSession,
    'start_tunnel' => l10n.mcpActionStartTunnel,
    'stop_tunnel' => l10n.mcpActionStopTunnel,
    'run_snippet' => l10n.mcpActionRunSnippet,
    'sftp_download' => l10n.mcpActionDownload,
    'sftp_upload' => l10n.mcpActionUpload,
    final other => l10n.mcpActionOther(other),
  };

  static String _label(AppLocalizations l10n, ApprovalDetailKind kind) =>
      switch (kind) {
        ApprovalDetailKind.command => l10n.mcpDetailCommand,
        ApprovalDetailKind.input => l10n.mcpDetailInput,
        ApprovalDetailKind.host => l10n.mcpDetailHost,
        ApprovalDetailKind.tunnel => l10n.mcpDetailTunnel,
        ApprovalDetailKind.snippet => l10n.mcpDetailSnippet,
        ApprovalDetailKind.remotePath => l10n.mcpDetailRemotePath,
        ApprovalDetailKind.localPath => l10n.mcpDetailLocalPath,
        ApprovalDetailKind.overwrite => l10n.mcpDetailOverwrite,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final request = widget.request;
    final mono = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: Mono.family,
      fontFamilyFallback: Mono.fallback,
    );

    Widget field(String label, String value, {bool code = false}) => Padding(
      padding: const EdgeInsets.only(top: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          if (value.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.xs),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText(value, style: code ? mono : null),
              ),
            ),
          ],
        ],
      ),
    );

    return AlertDialog(
      key: const Key('mcp.approval'),
      icon: Icon(PiconsRegular.shieldWarning, color: scheme.error),
      title: Text(l10n.mcpApprovalTitle(request.clientName, _action(l10n))),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.maxMessageWidth,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.mcpApprovalNote, style: theme.textTheme.bodySmall),
              field(l10n.mcpApprovalTarget, request.target),
              for (final detail in request.details)
                field(
                  _label(l10n, detail.kind),
                  detail.value,
                  code:
                      detail.kind != ApprovalDetailKind.snippet &&
                      detail.kind != ApprovalDetailKind.tunnel,
                ),
              if (request.canRememberSimilar)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.md),
                  child: CheckboxListTile(
                    key: const Key('mcp.approval.remember'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _remember,
                    onChanged: (value) =>
                        setState(() => _remember = value ?? false),
                    title: Text(
                      l10n.mcpApprovalRemember(widget.rememberMinutes),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('mcp.approval.deny'),
          autofocus: true,
          onPressed: () => _close(ApprovalDecision.deny),
          child: Text(l10n.mcpApprovalDeny),
        ),
        FilledButton(
          key: const Key('mcp.approval.approve'),
          onPressed: () => _close(
            _remember
                ? ApprovalDecision.approveSimilar
                : ApprovalDecision.approveOnce,
          ),
          child: Text(l10n.mcpApprovalApprove),
        ),
      ],
    );
  }
}
