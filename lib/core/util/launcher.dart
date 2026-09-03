import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Everything the app does by handing the user off to another app.
///
/// Each entry swallows its failure and reports through [onError] rather than
/// throwing: a missing browser or mail client is not an app error, and a
/// crash here would be a much worse outcome than a snackbar.
abstract final class Launcher {
  /// Open an arbitrary URL in the platform browser.
  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      developer.log(
        'could not open $url',
        name: 'launcher',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Open the app's store listing.
  ///
  /// Prefers the native `market://` scheme on Android so the Play app opens
  /// directly instead of bouncing through a browser; falls back to the web
  /// listing when Play is absent (an emulator, a sideloaded build).
  static Future<bool> openStoreListing() async {
    if (!kIsWeb && Platform.isAndroid) {
      final market = Uri.parse(
        'market://details?id=${AppConfig.androidApplicationId}',
      );
      try {
        if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // Play is not installed. The web listing below still works.
      }
    }
    return openUrl(AppConfig.storeListingUrl);
  }

  /// Share a short blurb plus the store link.
  static Future<void> shareApp(String message) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: '$message\n\n${AppConfig.storeListingUrl}'),
      );
    } catch (error, stackTrace) {
      developer.log(
        'share failed',
        name: 'launcher',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Share arbitrary text — a diagnostics report, an exported note.
  ///
  /// Separate from [shareApp] because that one appends the store link, which
  /// is right for a recommendation and wrong for everything else.
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } catch (error, stackTrace) {
      developer.log(
        'share failed',
        name: 'launcher',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
