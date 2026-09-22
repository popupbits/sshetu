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
  static const String knownHosts = '/settings/known-hosts';

  /// Moving a configuration to another device, and the two halves of it.
  /// Children of Settings, so their paths carry that prefix — the router
  /// declares them under the settings branch and a constant that disagrees
  /// resolves to nothing at all.
  static const String transferSend = '/settings/transfer/send';
  static const String transferReceive = '/settings/transfer/receive';
  static const String backupExport = '/settings/backup/export';
  static const String backupImport = '/settings/backup/restore';
  static const String diagnostics = '/settings/diagnostics';
  static const String splash = '/splash';

  /// Add a host.
  static const String hostNew = '/hosts/new';

  /// Edit the host with this id.
  static const String hostEdit = '/hosts/edit';

  /// One session's terminal.
  static const String terminal = '/terminal';

  /// Read an existing OpenSSH setup off this machine.
  static const String importOpenSsh = '/import';

  static String hostEditFor(String id) => '$hostEdit/$id';

  static String terminalFor(String sessionId) => '$terminal/$sessionId';

  /// Add a port forward.
  static const String tunnelNew = '/tunnels/new';

  /// Edit the port forward with this id.
  static const String tunnelEdit = '/tunnels/edit';

  static String tunnelEditFor(String id) => '$tunnelEdit/$id';

  /// Add a forward already scoped to one host — the ordinary way in, since
  /// the screen groups forwards by host and "add" always starts from a
  /// section that already knows which one.
  static String tunnelNewFor(String hostId) => '$tunnelNew?host=$hostId';

  /// Saved commands.
  static const String snippets = '/snippets';

  /// Add a snippet.
  static const String snippetNew = '/snippets/new';

  /// Edit the snippet with this id.
  static const String snippetEdit = '/snippets/edit';

  static String snippetEditFor(String id) => '$snippetEdit/$id';

  /// The SFTP browser for one session's connection.
  static const String files = '/files';

  /// The file browser for the session with this id — see [terminalFor].
  static String filesFor(String sessionId) => '$files/$sessionId';

  /// The import screen, limited to one kind of thing.
  ///
  /// Opening "import keys" and being shown a list of servers — every one of
  /// them ticked — is not what the user asked for, and ticking them by default
  /// means a stray tap imports things they never wanted.
  static String importFocused(String focus) => '$importOpenSsh?focus=$focus';

  /// Where the app opens.
  static const String initial = hosts;
}
