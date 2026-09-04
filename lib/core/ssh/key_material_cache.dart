import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ssh_credentials.dart';

/// Private keys already read out of the credential store, for this app run.
///
/// **Why this is shared rather than per connection.** Reading a key is a real
/// credential-store lookup, and on macOS's login keychain each one can raise
/// its own authorisation prompt. A host that names no key is offered every key
/// the user has — which is what `ssh` does — so a connection costs one prompt
/// per key, and a *second* connection used to cost the same again because the
/// cache died with the first. Connecting to three servers meant six prompts
/// for two keys.
///
/// **What it costs.** The material stays in memory for the app run instead of
/// for one connection. That is the ssh-agent model, and the honest comparison
/// is not "in memory versus not" — a connection already holds every key it
/// offered for as long as it lives, and people keep sessions open all day. It
/// is the difference between reading them once and reading them repeatedly.
///
/// It holds no passwords. A password is something the user typed, and it
/// should not outlive the attempt it was typed for; a key is a file they
/// already stored.
class KeyMaterialCache {
  final Map<String, SshPrivateKey> _keys = {};

  SshPrivateKey? operator [](String identityId) => _keys[identityId];

  void operator []=(String identityId, SshPrivateKey key) =>
      _keys[identityId] = key;

  /// Forgets one key. Called when an identity changes or is deleted, so a
  /// replaced key is never offered from a stale copy.
  void forget(String identityId) => _keys.remove(identityId);

  /// Forgets everything.
  void clear() => _keys.clear();

  int get length => _keys.length;
}

final keyMaterialCacheProvider = Provider<KeyMaterialCache>(
  (ref) => KeyMaterialCache(),
);
