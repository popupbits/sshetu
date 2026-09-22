import 'package:material_ui/material_ui.dart';

import '../config/app_config.dart';
import '../theme/tokens.dart';

/// A small "DEBUG" pill, shown only by a debug build.
///
/// A debug build is a separate app ("SSHetu Debug") with its own data, and
/// it looks exactly like the real one. The pill is what stops a screenshot,
/// a bug report or a QA run from being mistaken for the release build — the
/// window title says so too, but screenshots crop it.
///
/// Renders nothing for release, so a release build lays out exactly as it
/// did before this existed. The word is not localized for the same reason
/// Flutter's own DEBUG banner is not: it describes the build, never appears
/// in one a user installs, and has to read the same in every bug report.
class DebugBadge extends StatelessWidget {
  const DebugBadge({this.identity = AppIdentity.current, super.key});

  /// Injectable so a test can show both builds without rebuilding.
  final AppIdentity identity;

  static const String label = 'DEBUG';

  @override
  Widget build(BuildContext context) {
    if (!identity.isDebug) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      label: identity.displayName,
      excludeSemantics: true,
      child: DecoratedBox(
        key: const Key('debugBadge'),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xxs,
          ),
          child: Text(
            label,
            style: style?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
