import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/terminal/tmux_install.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../tmux_install_assistant.dart';

/// The offer to install tmux, drawn over a tab whose server lacks it.
///
/// A banner rather than a dialog: it never blocks the terminal, which keeps
/// working underneath while the user decides. Shows the exact command that
/// would run before anything does. Stateless — the stage and the actions
/// come from [TmuxInstallAssistant] — so every state can be drawn in a test.
class TmuxInstallPrompt extends StatelessWidget {
  const TmuxInstallPrompt({
    required this.stage,
    required this.hostLabel,
    required this.onInstall,
    required this.onInstallWithUpdate,
    required this.onNotNow,
    required this.onNever,
    required this.onRestart,
    required this.onDismiss,
    super.key,
  });

  final TmuxInstallStage stage;
  final String hostLabel;
  final VoidCallback onInstall;
  final VoidCallback onInstallWithUpdate;
  final VoidCallback onNotNow;
  final VoidCallback onNever;
  final VoidCallback onRestart;
  final VoidCallback onDismiss;

  /// How much of a failed install's output is shown: the end is where the
  /// reason is.
  static const int _outputLines = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stage = this.stage;

    final body = switch (stage) {
      TmuxInstallIdle() ||
      TmuxInstallDetecting() ||
      TmuxInstallDismissed() => null,
      TmuxInstallOffered(offer: final RunInstall offer) => _Body(
        icon: PiconsRegular.package,
        message: l10n.tmuxInstallPrompt(hostLabel),
        command: offer.command,
        commandLabel: l10n.tmuxInstallCommandLabel,
        actions: [
          _Action.primary(
            key: const Key('tmuxInstall.install'),
            label: l10n.tmuxInstallAction,
            onPressed: onInstall,
          ),
          ..._decline(l10n),
        ],
      ),
      TmuxInstallOffered(offer: final TypeInstallInTerminal offer) => _Body(
        icon: PiconsRegular.package,
        message: l10n.tmuxInstallPrompt(hostLabel),
        command: offer.command,
        commandLabel: l10n.tmuxInstallCommandLabelTerminal,
        note: l10n.tmuxInstallPasswordNote,
        actions: [
          _Action.primary(
            key: const Key('tmuxInstall.install'),
            label: l10n.tmuxInstallActionTerminal,
            onPressed: onInstall,
          ),
          ..._decline(l10n),
        ],
      ),
      TmuxInstallOffered(offer: final InstallUnavailable offer) => _Body(
        icon: PiconsRegular.info,
        message: switch (offer.reason) {
          InstallUnavailableReason.unknownPackageManager =>
            l10n.tmuxInstallUnknownManager(hostLabel),
          InstallUnavailableReason.noPrivilege => l10n.tmuxInstallNoPrivilege(
            hostLabel,
          ),
        },
        actions: _decline(l10n),
      ),
      // Planned into [TmuxInstallSucceeded] by the assistant; drawn the same
      // way should it ever arrive here.
      TmuxInstallOffered(offer: TmuxAlreadyPresent()) ||
      TmuxInstallSucceeded() => _Body(
        icon: PiconsRegular.checkCircle,
        message: l10n.tmuxInstallSucceeded,
        actions: [
          _Action.primary(
            key: const Key('tmuxInstall.restart'),
            label: l10n.tmuxInstallRestart,
            onPressed: onRestart,
          ),
          _Action(
            key: const Key('tmuxInstall.later'),
            label: l10n.tmuxInstallLater,
            onPressed: onDismiss,
          ),
        ],
      ),
      TmuxInstallRunning(:final offer) => _Body(
        busy: true,
        message: l10n.tmuxInstallRunning(hostLabel),
        command: offer.command,
        actions: const [],
      ),
      TmuxInstallFailed(:final output, :final retry) => _Body(
        icon: PiconsRegular.warning,
        failed: true,
        message: retry == null
            ? l10n.tmuxInstallFailed
            : l10n.tmuxInstallFailedStaleLists,
        output: _tail(output),
        command: retry?.command,
        commandLabel: retry == null ? null : l10n.tmuxInstallCommandLabel,
        actions: [
          if (retry != null)
            _Action.primary(
              key: const Key('tmuxInstall.update'),
              label: l10n.tmuxInstallUpdateAction,
              onPressed: onInstallWithUpdate,
            ),
          _Action(
            key: const Key('tmuxInstall.dismiss'),
            label: l10n.tmuxInstallDismiss,
            onPressed: onDismiss,
          ),
        ],
      ),
      TmuxInstallTyped() => _Body(
        icon: PiconsRegular.keyboard,
        message: l10n.tmuxInstallTyped,
        actions: [
          _Action.primary(
            key: const Key('tmuxInstall.restart'),
            label: l10n.tmuxInstallRestart,
            onPressed: onRestart,
          ),
          _Action(
            key: const Key('tmuxInstall.dismiss'),
            label: l10n.tmuxInstallDismiss,
            onPressed: onDismiss,
          ),
        ],
      ),
    };

    if (body == null) return const SizedBox.shrink();
    return body;
  }

  List<_Action> _decline(AppLocalizations l10n) => [
    _Action(
      key: const Key('tmuxInstall.notNow'),
      label: l10n.tmuxInstallNotNow,
      onPressed: onNotNow,
    ),
    _Action(
      key: const Key('tmuxInstall.never'),
      label: l10n.tmuxInstallNever,
      onPressed: onNever,
    ),
  ];

  static String? _tail(String output) {
    final lines = output.trimRight().split('\n');
    if (lines.length == 1 && lines.single.trim().isEmpty) return null;
    return lines
        .skip(lines.length > _outputLines ? lines.length - _outputLines : 0)
        .join('\n');
  }
}

class _Action {
  const _Action({
    required this.key,
    required this.label,
    required this.onPressed,
  }) : primary = false;

  const _Action.primary({
    required this.key,
    required this.label,
    required this.onPressed,
  }) : primary = true;

  final Key key;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
}

class _Body extends StatelessWidget {
  const _Body({
    required this.message,
    required this.actions,
    this.icon,
    this.busy = false,
    this.failed = false,
    this.command,
    this.commandLabel,
    this.note,
    this.output,
  });

  final String message;
  final List<_Action> actions;
  final IconData? icon;
  final bool busy;
  final bool failed;
  final String? command;
  final String? commandLabel;
  final String? note;
  final String? output;

  /// Tall enough for the end of an error, short enough that the terminal
  /// underneath keeps most of a phone's screen.
  static const double _maxOutputHeight = 120;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = failed ? scheme.onErrorContainer : scheme.onSurface;
    final muted = failed ? scheme.onErrorContainer : scheme.onSurfaceVariant;
    final mono = Mono.apply(theme.textTheme.bodySmall);

    Widget codeBox(String text, {Key? key}) => Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: SelectableText(
        text,
        style: mono.copyWith(color: scheme.onSurface),
      ),
    );

    return Material(
      key: const Key('tmuxInstall.banner'),
      color: failed ? scheme.errorContainer : scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.sm,
          Spacing.md,
          Spacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.xxs),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : Icon(icon, size: 16, color: muted),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            if (output != null) ...[
              const SizedBox(height: Spacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _maxOutputHeight),
                child: SingleChildScrollView(
                  reverse: true,
                  child: codeBox(output!, key: const Key('tmuxInstall.output')),
                ),
              ),
            ],
            if (command != null) ...[
              const SizedBox(height: Spacing.sm),
              if (commandLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Text(
                    commandLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
              codeBox(command!, key: const Key('tmuxInstall.command')),
            ],
            if (note != null) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                note!,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ],
            if (actions.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                // Wraps onto a second line on a phone rather than
                // overflowing: three buttons do not fit 360 points.
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: Spacing.xs,
                  children: [
                    for (final action in actions)
                      action.primary
                          ? FilledButton.tonal(
                              key: action.key,
                              onPressed: action.onPressed,
                              child: Text(action.label),
                            )
                          : TextButton(
                              key: action.key,
                              onPressed: action.onPressed,
                              style: failed
                                  ? TextButton.styleFrom(
                                      foregroundColor: scheme.onErrorContainer,
                                    )
                                  : null,
                              child: Text(action.label),
                            ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
