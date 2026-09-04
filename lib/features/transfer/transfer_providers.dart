import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'transfer_session.dart';

/// The step that gets permission to accept incoming connections.
///
/// Behind a provider so a test can hold it open and prove the send screen goes
/// on painting while it waits. That is the whole claim being made by moving
/// the first `listen()` off this isolate, and it is worth being able to check.
final listenPermissionProvider = Provider<Future<void> Function()>(
  (ref) => askToListen,
);
