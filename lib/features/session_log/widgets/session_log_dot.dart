import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../session_log_controller.dart';

/// A small red dot while [sessionId] is being logged, naming the file in its
/// tooltip. Nothing at all otherwise — not even its [leading] gap — so it can
/// sit in any header for free.
///
/// Solid for recording, the convention every recorder uses; a ring when the
/// log has grown past its size warning, so the change is a shape and not
/// only a shade.
class SessionLogDot extends ConsumerWidget {
  const SessionLogDot({
    required this.sessionId,
    this.size = 8,
    this.leading = 0,
    super.key,
  });

  final String sessionId;
  final double size;

  /// Space before the dot, drawn only with it.
  final double leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(
      sessionLogControllerProvider.select((logs) => logs[sessionId]),
    );
    if (log == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.error;
    final label = log.oversized
        ? l10n.sessionLogLarge(log.fileName)
        : l10n.sessionLogIndicator(log.fileName);

    return Padding(
      padding: EdgeInsets.only(left: leading),
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: Container(
            key: ValueKey('sessionLog.dot.$sessionId'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: log.oversized ? Colors.transparent : color,
              border: log.oversized
                  ? Border.all(color: color, width: BorderWidths.thick)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
