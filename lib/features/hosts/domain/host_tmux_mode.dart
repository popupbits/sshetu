/// Whether a host's terminal tabs are kept running on the server in tmux.
///
/// The app-wide setting ("Keep sessions running on the server") is the
/// default; a host can override it either way. Stored in `hosts.tmux_mode`
/// (v7) as NULL for [followDefault], or `always` / `never`.
enum HostTmuxMode {
  /// Follow the app-wide setting. Stored as NULL.
  followDefault(null),

  /// Always try tmux on this host, whatever the setting says.
  always('always'),

  /// Never use tmux on this host — and never offer to install it.
  never('never');

  const HostTmuxMode(this.storageValue);

  /// The column's value: null for [followDefault].
  final String? storageValue;

  /// The value the JSON export writes: `default`, `always` or `never`.
  String get exportValue => storageValue ?? 'default';

  /// Reads a stored or exported value. NULL, `default`, a missing key and
  /// anything this build does not know all follow the default — a value
  /// written by a newer build must not crash this one, and "the setting
  /// decides" is the reading that changes nothing.
  static HostTmuxMode fromStorage(String? value) => switch (value) {
    'always' => HostTmuxMode.always,
    'never' => HostTmuxMode.never,
    _ => HostTmuxMode.followDefault,
  };

  /// Whether a new tab to a host in this mode tries tmux, given the app-wide
  /// setting [globalDefault].
  bool resolve({required bool globalDefault}) => switch (this) {
    HostTmuxMode.followDefault => globalDefault,
    HostTmuxMode.always => true,
    HostTmuxMode.never => false,
  };
}
