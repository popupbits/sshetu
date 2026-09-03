/// Every route path in the app, in one place.
///
/// Paths are data, so they live here regardless of which router is wired up.
/// Feature code refers to these constants and calls `context.goTo(...)`, which
/// keeps screens from importing the router package directly.
abstract final class Routes {
  static const String hosts = '/hosts';
  static const String sessions = '/sessions';
  static const String keys = '/keys';
  static const String tunnels = '/tunnels';
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String diagnostics = '/settings/diagnostics';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String splash = '/splash';

  /// Where the app opens.
  static const String initial = hosts;
}
