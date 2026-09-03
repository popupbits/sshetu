import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

/// Thin wrapper around Google Play Core's flexible in-app update API.
///
/// Every method is Android-only and swallows its errors: a failed update check
/// is never a user-facing problem, and callers can treat a null result as "no
/// update". On non-Play installs (debug, sideloaded) and every other platform
/// these are no-ops.
class AppUpdateService {
  const AppUpdateService({@visibleForTesting this.debugIsAndroid});

  /// Forces the Android branch on in tests, where Platform.isAndroid is false.
  @visibleForTesting
  final bool? debugIsAndroid;

  // dart:io's Platform is unimplemented on the web — touching any member
  // throws — so short-circuit on kIsWeb before reading it.
  bool get _isAndroid => debugIsAndroid ?? (!kIsWeb && Platform.isAndroid);

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!_isAndroid) return null;
    try {
      return await InAppUpdate.checkForUpdate();
    } catch (error, stackTrace) {
      _log('checkForUpdate', error, stackTrace);
      return null;
    }
  }

  Future<AppUpdateResult?> startFlexibleUpdate() async {
    if (!_isAndroid) return null;
    try {
      return await InAppUpdate.startFlexibleUpdate();
    } catch (error, stackTrace) {
      _log('startFlexibleUpdate', error, stackTrace);
      return null;
    }
  }

  Future<void> completeFlexibleUpdate() async {
    if (!_isAndroid) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (error, stackTrace) {
      _log('completeFlexibleUpdate', error, stackTrace);
    }
  }

  void _log(String operation, Object error, StackTrace stackTrace) {
    developer.log(
      'AppUpdateService.$operation failed',
      name: 'AppUpdateService',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => const AppUpdateService(),
);
