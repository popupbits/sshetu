import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_manager.dart';

/// A request for a session's pane to open its find bar.
///
/// The find bar belongs to the pane, but the ways of asking for it do not: the
/// menu bar, the app-wide shortcut and the phone's app bar all sit above it.
/// They publish a request here and the pane showing that session answers it.
/// [serial] makes two requests in a row distinct, so asking again while the
/// bar is open still refocuses its field.
@immutable
class TerminalFindRequest {
  const TerminalFindRequest(this.sessionId, this.serial);

  final String sessionId;
  final int serial;
}

/// The latest find request, or null before the first one.
final terminalFindRequestProvider =
    NotifierProvider<TerminalFindRequests, TerminalFindRequest?>(
      TerminalFindRequests.new,
    );

class TerminalFindRequests extends Notifier<TerminalFindRequest?> {
  var _serial = 0;

  @override
  TerminalFindRequest? build() => null;

  void request(String sessionId) =>
      state = TerminalFindRequest(sessionId, ++_serial);
}

/// Opens the find bar on the active session, if there is one. Shared by the
/// shortcut, the menu item and the phone's app bar so they cannot drift.
void openTerminalFind(WidgetRef ref) {
  final id = ref.read(sessionManagerProvider.notifier).activeId;
  if (id != null) ref.read(terminalFindRequestProvider.notifier).request(id);
}
