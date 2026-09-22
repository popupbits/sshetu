import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/ssh/reconnect_loop.dart';
import '../../../core/terminal/terminal_session.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';

/// The bar drawn over a pane whose session is not live.
///
/// A terminal that cannot be typed into looks exactly like one that can — a
/// prompt is a prompt whether it is live or a week old. This says which, in
/// words, and carries the way back: a countdown with "Retry now" and "Stop"
/// while a dropped session reconnects by itself, and a plain Reconnect once
/// it is not going to — because the user ended it, the shell exited, or the
/// server now refuses it.
class PaneStatusBar extends StatefulWidget {
  const PaneStatusBar({
    required this.session,
    this.clock = DateTime.now,
    super.key,
  });

  final TerminalSession session;

  /// Injected so a test can pin the countdown.
  final DateTime Function() clock;

  @override
  State<PaneStatusBar> createState() => _PaneStatusBarState();
}

class _PaneStatusBarState extends State<PaneStatusBar> {
  /// Ticks the countdown once a second, and only while there is one.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
    _sync();
  }

  @override
  void didUpdateWidget(PaneStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      oldWidget.session.removeListener(_onSessionChanged);
      widget.session.addListener(_onSessionChanged);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _sync() {
    final counting = widget.session.reconnect.phase == ReconnectPhase.waiting;
    if (counting && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!counting) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// The session changed: redraw, and start or stop the countdown.
  void _onSessionChanged() {
    _sync();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final l10n = AppLocalizations.of(context);
    final loop = session.reconnect;

    if (session.status == TerminalSessionStatus.connecting) {
      return _Bar(
        busy: true,
        text: loop.isActive
            ? l10n.terminalReconnecting
            : l10n.terminalConnecting,
        actions: [
          if (loop.isActive)
            _BarButton(
              label: l10n.terminalStopReconnecting,
              onPressed: session.stopReconnecting,
            ),
        ],
      );
    }

    final nextAt = loop.nextAttemptAt;
    if (loop.phase == ReconnectPhase.waiting && nextAt != null) {
      final remaining = nextAt.difference(widget.clock());
      // Rounded up: "in 0 s" while still waiting reads as stuck.
      final seconds = (remaining.inMilliseconds / 1000).ceil().clamp(0, 999);
      final attempt = loop.attemptsMade + 1;
      return _Bar(
        icon: PiconsRegular.plugsConnected,
        text: context.isCompact
            ? l10n.terminalReconnectWaitingShort(seconds)
            : l10n.terminalReconnectWaiting(seconds, attempt),
        actions: [
          _BarButton(label: l10n.terminalRetryNow, onPressed: loop.retryNow),
          _BarButton(
            label: l10n.terminalStopReconnecting,
            onPressed: session.stopReconnecting,
          ),
        ],
      );
    }

    final failed = session.status == TerminalSessionStatus.failed;
    return _Bar(
      failed: failed,
      icon: failed ? PiconsRegular.warning : PiconsRegular.plugsConnected,
      // The failure's own words when there are any: "connection refused" is
      // worth more than "disconnected".
      text: session.error ?? l10n.terminalSessionEnded,
      actions: [
        _BarButton(label: l10n.terminalReconnect, onPressed: session.start),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.text,
    this.actions = const [],
    this.icon,
    this.busy = false,
    this.failed = false,
  });

  final String text;
  final List<Widget> actions;
  final IconData? icon;
  final bool busy;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = failed ? scheme.onErrorContainer : null;

    return Material(
      color: failed ? scheme.errorContainer : scheme.surfaceContainerHigh,
      child: SizedBox(
        height: Chrome.statusBar,
        child: Row(
          children: [
            const SizedBox(width: Spacing.md),
            if (busy)
              const SizedBox.square(
                dimension: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 12,
                color: foreground ?? scheme.onSurfaceVariant,
              ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: foreground),
              ),
            ),
            ...actions,
            const SizedBox(width: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}
