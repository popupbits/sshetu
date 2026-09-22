import 'package:sshetu/core/terminal/tmux_install.dart';

/// Output of [tmuxInstallProbeCommand] as a server would print it: a login
/// banner, then the answer lines.
String probe({
  String uid = '1000',
  String kernel = 'Linux',
  List<String> managers = const [],
  String? osId,
  String? osLike,
  String sudo = 'password',
  bool tmux = false,
  String banner = 'Welcome to the server!\r\n',
}) => [
  banner,
  TmuxInstallMarkers.begin,
  '${TmuxInstallMarkers.uid}$uid',
  '${TmuxInstallMarkers.kernel}$kernel',
  for (final m in managers) '${TmuxInstallMarkers.manager}$m',
  if (osId != null) '${TmuxInstallMarkers.osId}$osId',
  if (osLike != null) '${TmuxInstallMarkers.osLike}$osLike',
  '${TmuxInstallMarkers.sudo}$sudo',
  '${TmuxInstallMarkers.tmux}${tmux ? 'yes' : 'no'}',
].join('\r\n');
