import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/terminal/terminal_find.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../session_shortcuts.dart';

/// The find-in-scrollback bar drawn at the top of a terminal pane.
///
/// A thin view over [TerminalFind]: the query field, the case and regex
/// toggles, "3 of 17", and older/newer. Enter goes further back, Shift+Enter
/// comes forward, Esc closes — the keys every find bar has, and the reason
/// they are bound on the field rather than on buttons nobody reaches for.
///
/// The pane owns the [TerminalFind] and closes the bar through [onClose],
/// which is also where focus goes back to the terminal.
class TerminalFindBar extends StatefulWidget {
  const TerminalFindBar({required this.find, required this.onClose, super.key});

  final TerminalFind find;
  final VoidCallback onClose;

  @override
  State<TerminalFindBar> createState() => TerminalFindBarState();
}

class TerminalFindBarState extends State<TerminalFindBar> {
  late final _text = TextEditingController(text: widget.find.query);
  final _focus = FocusNode(debugLabel: 'terminal-find');

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
    // Not `autofocus`: that only applies when nothing in the scope has focus
    // yet, and the terminal always does. So focus is taken explicitly, with a
    // query kept from last time selected — typing replaces it, Enter reuses it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Puts the cursor in the field with its text selected — what pressing the
  /// find shortcut again while the bar is open should do.
  void focus() {
    _focus.requestFocus();
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
  }

  void _onTextChanged() => widget.find.query = _text.text;

  String _status(AppLocalizations l10n, TerminalFind find) {
    if (find.invalidPattern) return l10n.terminalFindInvalidPattern;
    if (find.query.isEmpty) return '';
    if (find.matchCount == 0) return l10n.terminalFindNoMatches;
    return find.capped
        ? l10n.terminalFindCountCapped(find.currentPosition, find.matchCount)
        : l10n.terminalFindCount(find.currentPosition, find.matchCount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: Chrome.tabStrip,
        child: ListenableBuilder(
          listenable: widget.find,
          builder: (context, _) {
            final find = widget.find;
            final hasMatches = find.matchCount > 0;
            final status = _status(l10n, find);

            return Row(
              children: [
                const SizedBox(width: Spacing.md),
                Icon(
                  PiconsRegular.magnifyingGlass,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.enter):
                          find.next,
                      const SingleActivator(LogicalKeyboardKey.numpadEnter):
                          find.next,
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        shift: true,
                      ): find.previous,
                      const SingleActivator(LogicalKeyboardKey.escape):
                          widget.onClose,
                      findInTerminalActivator(): focus,
                    },
                    child: TextField(
                      key: const ValueKey('terminal-find-field'),
                      controller: _text,
                      focusNode: _focus,
                      style: theme.textTheme.bodyMedium,
                      textInputAction: TextInputAction.search,
                      // The software keyboard's search key. On a hardware
                      // keyboard Enter is taken by the binding above first.
                      onSubmitted: (_) {
                        find.next();
                        _focus.requestFocus();
                      },
                      decoration: InputDecoration(
                        hintText: l10n.terminalFindHint,
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm,
                        ),
                      ),
                    ),
                  ),
                ),
                if (status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                    child: Text(
                      status,
                      key: const ValueKey('terminal-find-status'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: find.invalidPattern
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                _BarButton(
                  tooltip: l10n.terminalFindCaseSensitive,
                  icon: PiconsRegular.textAa,
                  selected: find.caseSensitive,
                  onPressed: () => find.caseSensitive = !find.caseSensitive,
                ),
                _BarButton(
                  tooltip: l10n.terminalFindRegex,
                  icon: PiconsRegular.asterisk,
                  selected: find.useRegex,
                  onPressed: () => find.useRegex = !find.useRegex,
                ),
                _BarButton(
                  tooltip: l10n.terminalFindOlder,
                  icon: PiconsRegular.caretUp,
                  onPressed: hasMatches ? find.next : null,
                ),
                _BarButton(
                  tooltip: l10n.terminalFindNewer,
                  icon: PiconsRegular.caretDown,
                  onPressed: hasMatches ? find.previous : null,
                ),
                _BarButton(
                  tooltip: l10n.terminalFindClose,
                  icon: PiconsRegular.x,
                  onPressed: widget.onClose,
                ),
                const SizedBox(width: Spacing.xs),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A compact icon button sized to the bar's row.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Null for a plain button; true or false for a toggle.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = selected ?? false;

    return IconButton(
      tooltip: tooltip,
      isSelected: selected,
      icon: Icon(icon, size: 16),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      style: on
          ? IconButton.styleFrom(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
            )
          : null,
      onPressed: onPressed,
    );
  }
}
