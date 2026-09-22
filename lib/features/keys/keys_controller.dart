import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ssh/key_generator.dart';
import '../../core/ssh/key_material_cache.dart';
import '../../core/ssh/private_key_inspector.dart';
import 'domain/ssh_identity.dart';

/// Every key the user has.
final identitiesProvider = FutureProvider<List<SshIdentity>>(
  (ref) => ref.watch(identityRepositoryProvider).all(),
);

/// Writes, each of which invalidates [identitiesProvider].
class IdentitiesController {
  const IdentitiesController(this._ref);

  final Ref _ref;

  Future<void> save(
    SshIdentity identity, {
    String? privateKey,
    String? passphrase,
  }) async {
    await _ref
        .read(identityRepositoryProvider)
        .save(identity, privateKey: privateKey, passphrase: passphrase);
    // A key that was just rewritten must not be offered from the copy read
    // before it changed.
    _ref.read(keyMaterialCacheProvider).forget(identity.id);
    _ref.invalidate(identitiesProvider);
  }

  /// Deletes the identity, then refreshes the list **whatever happened**.
  ///
  /// The row is tombstoned before the vault is touched, so by the time a
  /// credential store refuses to erase the material the deletion has already
  /// happened. Letting that refusal skip the refresh left the key on screen
  /// until the app was restarted — the user had deleted it, the database
  /// agreed, and only the list disagreed.
  ///
  /// The error is still thrown, because "SSHetu has forgotten this key but
  /// the keychain would not erase it" is something the person deleting key
  /// material deserves to be told.
  Future<void> delete(String id) async {
    try {
      await _ref
          .read(identityRepositoryProvider)
          .delete(id, now: DateTime.now().toUtc());
    } finally {
      _ref.read(keyMaterialCacheProvider).forget(id);
      _ref.invalidate(identitiesProvider);
    }
  }
}

final identitiesControllerProvider = Provider<IdentitiesController>(
  IdentitiesController.new,
);

/// Makes a key, off the UI isolate.
typedef KeyGeneratorFn = Future<GeneratedKey> Function(
  SshKeyType type, {
  String comment,
  String? passphrase,
});

/// Reads a pasted private key, off the UI isolate.
typedef KeyInspectorFn = Future<KeyInspection> Function(
  String text, {
  String? passphrase,
});

/// The key generator the sheets use. A provider so a widget test can swap
/// the background isolate — which a fake-async test clock never lets finish —
/// for a synchronous call.
final keyGeneratorProvider = Provider<KeyGeneratorFn>(
  (ref) => SshKeyGenerator.generateInBackground,
);

/// The pasted-key reader the paste sheet uses. A provider for the same reason
/// as [keyGeneratorProvider].
final keyInspectorProvider = Provider<KeyInspectorFn>(
  (ref) => inspectPrivateKeyInBackground,
);
