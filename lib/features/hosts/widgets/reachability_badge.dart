import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/reachability.dart';
import '../domain/ssh_host.dart';
import '../hosts_controller.dart';
import '../reachability_controller.dart';

/// A host row's avatar with its reachability dot in the corner.
///
/// On the avatar rather than beside the name so it costs the row no width —
/// at 360 px the name already competes with tags and markers for every pixel.
/// The state is in the semantics label and the tooltip, never only in the
/// colour, and the dot's **shape** differs too: filled when up, a ring when
/// down, a thin ring when unknown. That also keeps up and down apart under an
/// accent whose primary is itself reddish.
class ReachabilityBadge extends ConsumerWidget {
  const ReachabilityBadge({required this.host, required this.child, super.key});

  final SshHost host;
  final Widget child;

  /// The dot's diameter.
  static const double dotSize = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (enabled, result) = ref.watch(
      reachabilityProvider.select((s) {
        final address = probeAddressOf(host);
        return (s.enabled, address == null ? null : s.results[address.key]);
      }),
    );
    final live = ref.watch(liveSessionHostsProvider);
    final hosts = live.hostIds.isEmpty
        ? const <SshHost>[]
        : ref.watch(hostsProvider).value ?? const <SshHost>[];
    final reachability = HostReachability.resolve(
      host: host,
      enabled: enabled,
      sessionConnected: sessionProves(host, live, hosts),
      result: result,
    );
    if (reachability.kind == HostReachabilityKind.hidden) return child;

    final l10n = AppLocalizations.of(context);
    final status = describe(l10n, reachability);
    final checked = result == null ? null : checkedAgo(l10n, result.checkedAt);
    final label = checked == null ? status : '$status, $checked';

    return Tooltip(
      message: checked == null ? status : '$status\n$checked',
      // Manual: a long press on the row opens its menu, and the tooltip must
      // not take that gesture. Hover still shows it on a desktop, and the
      // label below is what a screen reader hears.
      triggerMode: TooltipTriggerMode.manual,
      excludeFromSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -Spacing.xxs,
            bottom: -Spacing.xxs,
            child: Semantics(
              label: label,
              child: _Dot(kind: reachability.kind),
            ),
          ),
        ],
      ),
    );
  }

  /// The state in words: "Reachable · 23 ms", "Unreachable (timed out)".
  static String describe(AppLocalizations l10n, HostReachability r) =>
      switch (r.kind) {
        HostReachabilityKind.session => l10n.reachabilitySession,
        HostReachabilityKind.up => l10n.reachabilityUp(
          r.result!.outcome.latency!.inMilliseconds,
        ),
        HostReachabilityKind.down => l10n.reachabilityDown(
          switch (r.result!.outcome.failure!) {
            ReachabilityFailure.timedOut => l10n.reachabilityTimedOut,
            ReachabilityFailure.refused => l10n.reachabilityRefused,
            ReachabilityFailure.unresolved => l10n.reachabilityUnresolved,
            ReachabilityFailure.unreachable => l10n.reachabilityNoRoute,
          },
        ),
        HostReachabilityKind.unknown ||
        HostReachabilityKind.hidden => l10n.reachabilityUnknown,
      };

  /// "Checked 2 min ago".
  static String checkedAgo(
    AppLocalizations l10n,
    DateTime at, {
    DateTime? now,
  }) {
    final elapsed = (now ?? DateTime.now()).difference(at);
    if (elapsed.inMinutes < 1) return l10n.reachabilityCheckedNow;
    if (elapsed.inHours < 1) {
      return l10n.reachabilityCheckedMinutes(elapsed.inMinutes);
    }
    return l10n.reachabilityCheckedHours(elapsed.inHours);
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.kind});

  final HostReachabilityKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final up =
        kind == HostReachabilityKind.up || kind == HostReachabilityKind.session;
    final down = kind == HostReachabilityKind.down;
    final ring = down ? scheme.error : scheme.outline;

    return Container(
      width: ReachabilityBadge.dotSize,
      height: ReachabilityBadge.dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Hollow dots are filled with the surface so the monogram's tint does
        // not show through and muddy the ring.
        color: up ? scheme.primary : scheme.surface,
        border: Border.all(
          color: up ? scheme.surface : ring,
          width: down ? BorderWidths.emphasis : BorderWidths.thick,
        ),
      ),
    );
  }
}
