import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Navigation verbs, so screens never import the router package.
///
/// Swapping routers means rewriting this file and nothing else.
extension AppNavigation on BuildContext {
  /// Replace the current location (tab switches, post-sign-in redirects).
  void goTo(String path) => go(path);

  /// Push on top, keeping the current screen underneath (details, forms).
  Future<T?> pushTo<T>(String path) => push<T>(path);

  /// Pop if there is anything to pop.
  void back() {
    if (canPop()) pop();
  }
}
