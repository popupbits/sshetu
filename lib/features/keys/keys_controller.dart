import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
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
      _ref.invalidate(identitiesProvider);
    }
  }
}

final identitiesControllerProvider = Provider<IdentitiesController>(
  IdentitiesController.new,
);
