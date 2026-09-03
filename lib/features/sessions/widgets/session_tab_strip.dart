import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/terminal/terminal_session.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../session_manager.dart';

/// The row of open sessions.
///
/// One [Chrome.tabStrip] row and no more. A terminal's scarcest resource is
/// vertical space, so the strip is not drawn at all when a single session is
/// open — the screen's own title bar is already that session's header, and a
/// second row saying the same thing would be pure cost.
class SessionTabStrip extends ConsumerWidget {
  const SessionTabStrip({
    this.actions = const [],
    this.alwaysShow = false,
    super.key,
  });

  /// Actions for the *selected* session, drawn at the end of the row.
  ///
  /// The desktop workspace has no AppBar — the panel header and this strip are
  /// its only chrome — so without somewhere here to put them, a session's
  /// actions have nowhere to live at all. That is how the file browser
  /// shipped reachable only on a phone.
  final List<Widget> actions;

  /// Draw the row even with a single session open.
  ///
  /// True on desktop, where this row *is* the pane's header and its actions;
  /// false on a phone, where the AppBar already names the session and a second
  /// row saying the same thing is pure cost.
  final bool alwaysShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionManagerProvider);
    final manager = ref.read(sessionManagerProvider.notifier);
    final activeId = manager.activeId;
    final scheme = Theme.of(context).colorScheme;

    if (sessions.isEmpty) return const SizedBox.shrink();
    if (sessions.length < 2 && !alwaysShow) return const SizedBox.shrink();

    return Container(
      height: Chrome.tabStrip,
      color: scheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _SessionTab(
                  session: session,
                  selected: session.id == activeId,
                  onTap: () => manager.select(session.id),
                  onClose: () => manager.close(session.id),
                );
              },
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  const _SessionTab({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final TerminalSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Material(
        // The selected tab takes the colour of the ground its content sits on,
        // so the tab and the terminal below read as one surface rather than
        // two stacked panels.
        color: selected ? scheme.surface : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: Chrome.tabStrip,
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.only(left: Spacing.md, right: Spacing.xs),
            decoration: BoxDecoration(
              border: Border(
                // Selection is a rule in the accent, not an outline: an outline
                // is invisible against a neutral ramp at this size.
                top: BorderSide(
                  color: selected ? scheme.primary : Colors.transparent,
                  width: Chrome.selectionRule,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LivenessDot(status: session.status),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                IconButton(
                  tooltip: l10n.terminalCloseTab,
                  onPressed: onClose,
                  icon: const Icon(PiconsRegular.x, size: 12),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 22,
                    height: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether a tab has a live session behind it.
///
/// A **shape**, not a tint on the label. Karmashala's shell makes the argument
/// and it holds here: whether a session is running is not something to say by
/// colouring its name — colour is already carrying selection, and a
/// red-vs-green label reads as an error rather than a state. A filled dot is
/// live, a hollow ring is not, and the difference survives being colour-blind.
class _LivenessDot extends StatelessWidget {
  const _LivenessDot({required this.status});

  final TerminalSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (status == TerminalSessionStatus.connecting) {
      return SizedBox.square(
        dimension: 8,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: scheme.primary,
        ),
      );
    }

    final live = status == TerminalSessionStatus.running;
    final failed = status == TerminalSessionStatus.failed;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: live ? scheme.primary : Colors.transparent,
        border: live
            ? null
            : Border.all(
                color: failed ? scheme.error : scheme.outline,
                width: 1.5,
              ),
      ),
    );
  }
}
