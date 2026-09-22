import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../reachability_controller.dart';

/// Tells the reachability scheduler whether [child] — the host list — can be
/// seen.
///
/// Seen means three things at once: mounted; the route and shell branch it is
/// in are the ones showing, which [TickerMode] reports (the shell keeps other
/// branches alive but offstage, and a route pushed over the list turns its
/// tickers off the same way); and the app not hidden or paused. `inactive`
/// still counts: on a desktop that only means the window lost focus, and the
/// list is still in plain view.
class ReachabilityScope extends ConsumerStatefulWidget {
  const ReachabilityScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReachabilityScope> createState() => _ReachabilityScopeState();
}

class _ReachabilityScopeState extends ConsumerState<ReachabilityScope> {
  late final AppLifecycleListener _lifecycle;

  /// Held so dispose, where `ref` can no longer be used, can still say the
  /// list has gone.
  late ReachabilityController _controller;
  late bool _foreground;
  bool _onStage = true;

  static bool _isForeground(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(reachabilityProvider.notifier);
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = _isForeground(state);
        _sync();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A dependency, so this runs again whenever the branch or route is shown
    // or hidden.
    _onStage = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    _controller = ref.read(reachabilityProvider.notifier)
      ..setVisible(this, _foreground && _onStage);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.setVisible(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
