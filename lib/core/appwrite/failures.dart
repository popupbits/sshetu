import 'package:appwrite/appwrite.dart';

/// A backend error, classified into something the UI can act on.
///
/// Screens should not branch on Appwrite's numeric codes: the mapping belongs
/// in one place, and "can the user retry?" is the only question most call
/// sites actually have.
sealed class AppwriteFailure implements Exception {
  const AppwriteFailure(this.message);

  final String message;

  /// Whether trying the same thing again could plausibly work.
  bool get isRetryable => this is NetworkFailure || this is ServerFailure;

  @override
  String toString() => message;
}

/// No usable connection, or the request timed out.
class NetworkFailure extends AppwriteFailure {
  const NetworkFailure([super.message = 'No connection']);
}

/// 401 / 403 — signed out, or not allowed.
class AuthFailure extends AppwriteFailure {
  const AuthFailure(super.message, {this.isUnauthenticated = false});

  /// True for 401, which should send the user back to sign-in rather than
  /// showing an error they can do nothing about.
  final bool isUnauthenticated;
}

/// 404.
class NotFoundFailure extends AppwriteFailure {
  const NotFoundFailure([super.message = 'Not found']);
}

/// 409 — already exists.
class ConflictFailure extends AppwriteFailure {
  const ConflictFailure(super.message);
}

/// 400 / 422 — the request was wrong.
class ValidationFailure extends AppwriteFailure {
  const ValidationFailure(super.message);
}

/// 429.
class RateLimitFailure extends AppwriteFailure {
  const RateLimitFailure([
    super.message = 'Too many attempts. Try again shortly.',
  ]);
}

/// 5xx, or anything unrecognised.
class ServerFailure extends AppwriteFailure {
  const ServerFailure([super.message = 'Something went wrong']);
}

/// Run an Appwrite call, translating its errors into [AppwriteFailure].
///
/// Wrap every SDK call in this. It is the only place that knows what an
/// Appwrite status code means.
Future<T> runAppwrite<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppwriteException catch (e) {
    throw _classify(e);
  } catch (e) {
    // A socket error, a DNS failure, a timeout — the SDK lets these through
    // untranslated, and they all mean the same thing to a user.
    throw NetworkFailure(e.toString());
  }
}

AppwriteFailure _classify(AppwriteException e) {
  final message = e.message ?? 'Something went wrong';
  return switch (e.code) {
    401 => AuthFailure(message, isUnauthenticated: true),
    403 => AuthFailure(message),
    404 => NotFoundFailure(message),
    409 => ConflictFailure(message),
    400 || 422 => ValidationFailure(message),
    429 => const RateLimitFailure(),
    final int code when code >= 500 => ServerFailure(message),
    _ => ServerFailure(message),
  };
}
