import 'dart:developer' as developer;

import 'package:in_app_review/in_app_review.dart';

import 'launcher.dart';

/// Asks for a store rating.
///
/// The native sheet is the good path: it never leaves the app and the store
/// counts it. But the platform decides whether to actually show it — it is
/// rate-limited per user, silently ignored in debug builds, and unavailable
/// on a device without the store app. `requestReview` returns normally in all
/// of those cases, so there is no way to detect that nothing appeared.
///
/// That is why [request] takes a [fallbackToStore]: from a Settings row the
/// user tapped deliberately, showing nothing is the wrong outcome, so the
/// store listing opens instead. From an automatic prompt after some
/// milestone, showing nothing is correct and the fallback should be off.
abstract final class ReviewPrompt {
  static final InAppReview _inAppReview = InAppReview.instance;

  static Future<void> request({bool fallbackToStore = true}) async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return;
      }
    } catch (error, stackTrace) {
      developer.log(
        'in-app review unavailable',
        name: 'review',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (fallbackToStore) await Launcher.openStoreListing();
  }
}
