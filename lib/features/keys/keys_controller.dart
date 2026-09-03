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

  Future<void> delete(String id) async {
    await _ref
        .read(identityRepositoryProvider)
        .delete(id, now: DateTime.now().toUtc());
    _ref.invalidate(identitiesProvider);
  }
}

final identitiesControllerProvider = Provider<IdentitiesController>(
  IdentitiesController.new,
);
