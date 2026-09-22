import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/client_setup.dart';
import '../mcp_audit_controller.dart';
import '../mcp_server_controller.dart';
import '../mcp_settings.dart';
import 'mcp_activity_dialog.dart';

/// Settings → Integrations: the MCP server's switch, its status, the access
/// token, ready-to-paste client setup, and the activity log.
///
/// The token stays masked until asked for — in the setup snippets too — and
/// every copy button copies the real thing.
class McpIntegrationTile extends ConsumerStatefulWidget {
  const McpIntegrationTile({super.key});

  @override
  ConsumerState<McpIntegrationTile> createState() => _McpIntegrationTileState();
}

class _McpIntegrationTileState extends ConsumerState<McpIntegrationTile> {
  bool _showToken = false;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) context.toast(AppLocalizations.of(context).mcpCopied);
  }

  Future<void> _regenerate() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await context.confirm(
      title: l10n.mcpTokenRegenerateTitle,
      message: l10n.mcpTokenRegenerateBody,
      confirmLabel: l10n.mcpTokenRegenerate,
      cancelLabel: l10n.actionCancel,
      isDestructive: true,
    );
    if (confirmed) {
      await ref.read(mcpSettingsProvider.notifier).regenerateToken();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(mcpSettingsProvider);
    final status = ref.watch(mcpServerControllerProvider);
    final calls = ref.watch(mcpAuditProvider.select((log) => log.length));
    final controller = ref.read(mcpSettingsProvider.notifier);
    final token = settings.token;
    final port = status.port ?? settings.port;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('mcp.enabled'),
          secondary: const Icon(PiconsRegular.robot),
          title: Text(l10n.mcpToggle),
          subtitle: Text(l10n.mcpToggleBody),
          isThreeLine: true,
          value: settings.enabled,
          onChanged: (value) => unawaited(controller.setEnabled(value)),
        ),
        if (settings.enabled) ...[
          ListTile(
            key: const Key('mcp.status'),
            leading: Icon(
              status.state == McpServerState.failed
                  ? PiconsRegular.warning
                  : PiconsRegular.plugsConnected,
              color: status.state == McpServerState.failed
                  ? theme.colorScheme.error
                  : null,
            ),
            title: Text(switch (status.state) {
              McpServerState.running => l10n.mcpStatusRunning(
                mcpEndpointUrl(port),
              ),
              McpServerState.failed => l10n.mcpStatusFailed(status.error ?? ''),
              _ => l10n.mcpStatusStarting,
            }),
            subtitle: status.fallback
                ? Text(l10n.mcpStatusFallback(settings.port, port))
                : null,
          ),
          if (token != null) ...[
            ListTile(
              key: const Key('mcp.token'),
              leading: const Icon(PiconsRegular.key),
              title: Text(l10n.mcpToken),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _showToken ? token : maskToken(token),
                    key: const Key('mcp.token.value'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: Mono.family,
                      fontFamilyFallback: Mono.fallback,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(l10n.mcpTokenBody),
                  const SizedBox(height: Spacing.xs),
                  Wrap(
                    spacing: Spacing.sm,
                    children: [
                      TextButton.icon(
                        key: const Key('mcp.token.reveal'),
                        icon: Icon(
                          _showToken
                              ? PiconsRegular.eyeSlash
                              : PiconsRegular.eye,
                        ),
                        label: Text(
                          _showToken ? l10n.mcpTokenHide : l10n.mcpTokenShow,
                        ),
                        onPressed: () =>
                            setState(() => _showToken = !_showToken),
                      ),
                      TextButton.icon(
                        key: const Key('mcp.token.copy'),
                        icon: const Icon(PiconsRegular.copy),
                        label: Text(l10n.mcpTokenCopy),
                        onPressed: () => unawaited(_copy(token)),
                      ),
                      TextButton.icon(
                        key: const Key('mcp.token.regenerate'),
                        icon: const Icon(PiconsRegular.arrowsClockwise),
                        label: Text(l10n.mcpTokenRegenerate),
                        onPressed: () => unawaited(_regenerate()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.mcpSetupTitle, style: theme.textTheme.titleSmall),
                  _SetupBlock(
                    key: const Key('mcp.setup.claude'),
                    label: l10n.mcpSetupClaude,
                    shown: claudeCodeSetup(
                      port,
                      _showToken ? token : maskToken(token),
                    ),
                    onCopy: () =>
                        unawaited(_copy(claudeCodeSetup(port, token))),
                  ),
                  _SetupBlock(
                    key: const Key('mcp.setup.json'),
                    label: l10n.mcpSetupJson,
                    shown: jsonClientSetup(
                      port,
                      _showToken ? token : maskToken(token),
                    ),
                    onCopy: () =>
                        unawaited(_copy(jsonClientSetup(port, token))),
                  ),
                ],
              ),
            ),
          ],
        ],
        ListTile(
          key: const Key('mcp.activity'),
          leading: const Icon(PiconsRegular.listBullets),
          title: Text(l10n.mcpActivity),
          subtitle: Text(l10n.mcpActivityBody(calls)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(showMcpActivity(context)),
        ),
      ],
    );
  }
}

/// One paste-ready snippet with its copy button.
class _SetupBlock extends StatelessWidget {
  const _SetupBlock({
    required this.label,
    required this.shown,
    required this.onCopy,
    super.key,
  });

  final String label;
  final String shown;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
              IconButton(
                tooltip: l10n.actionCopy,
                icon: const Icon(PiconsRegular.copy),
                onPressed: onCopy,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.xs),
            ),
            child: SelectableText(
              shown,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: Mono.family,
                fontFamilyFallback: Mono.fallback,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
