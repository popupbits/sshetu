import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/appwrite/client.dart';
import '../../core/appwrite/failures.dart';

/// The signed-in user, or null.
///
/// State is *derived* from `account.get()` rather than tracked by hand: the
/// SDK owns the session cookie, so asking it who we are is the only answer
/// that cannot go stale.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, models.User?>(AuthController.new);

/// Convenience for widgets that only need the current user.
final currentUserProvider = Provider<models.User?>(
  (ref) => ref.watch(authControllerProvider).value,
);

class AuthController extends AsyncNotifier<models.User?> {
  @override
  Future<models.User?> build() => _currentUser();

  Future<models.User?> _currentUser() async {
    final appwrite = ref.read(appwriteProvider);
    try {
      return await appwrite.account.get();
    } on AppwriteException catch (e) {
      // 401 is the ordinary signed-out case, not an error worth surfacing.
      if (e.code == 401) return null;
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final appwrite = ref.read(appwriteProvider);
      await runAppwrite(
        () => appwrite.account.createEmailPasswordSession(
          email: email,
          password: password,
        ),
      );
      return _currentUser();
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final appwrite = ref.read(appwriteProvider);
      await runAppwrite(
        () => appwrite.account.create(
          userId: ID.unique(),
          email: email,
          password: password,
          name: name,
        ),
      );
      // Appwrite does not sign a new account in, so do it here — otherwise
      // the user lands back on sign-in having just typed these credentials.
      await runAppwrite(
        () => appwrite.account.createEmailPasswordSession(
          email: email,
          password: password,
        ),
      );
      return _currentUser();
    });
  }

  Future<void> signOut() async {
    final appwrite = ref.read(appwriteProvider);
    state = const AsyncLoading();
    try {
      await runAppwrite(
        () => appwrite.account.deleteSession(sessionId: 'current'),
      );
    } on AppwriteFailure {
      // The session was already gone server-side. Locally we are signed out
      // either way, which is what the user asked for.
    }
    state = const AsyncData(null);
  }

  /// Send a password-reset email.
  ///
  /// [redirectUrl] must be a page that can read `userId` and `secret` from the
  /// query string and call `updateRecovery`.
  Future<void> requestRecovery({
    required String email,
    required String redirectUrl,
  }) async {
    final appwrite = ref.read(appwriteProvider);
    await runAppwrite(
      () => appwrite.account.createRecovery(email: email, url: redirectUrl),
    );
  }

  /// Re-read the user, e.g. after email verification.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_currentUser);
  }
}
