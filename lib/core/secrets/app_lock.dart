import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import 'device_authenticator.dart';

/// What happened when the user flipped the credential-lock switch.
enum AppLockChange {
  /// The lock is now on.
  enabled,

  /// The lock is now off.
  disabled,

  /// The user did not confirm; nothing changed.
  cancelled,

  /// The device has no screen lock, biometric or Windows Hello to check
  /// against, so the lock was not turned on.
  unavailable,

  /// The device refused after too many attempts; nothing changed.
  lockedOut,

  /// The prompt ran and failed; nothing changed.
  failed,
}

/// Turns the credential lock on and off — the only way either happens.
///
/// **On requires a successful unlock first.** A lock the device cannot satisfy
/// is a lockout the user walked into from Settings: if there is no screen lock
/// to fall back on, the switch refuses and says why instead of storing a
/// setting that would make every saved credential unreadable.
///
/// **Off requires one too, when the device can ask.** Otherwise the lock
/// protects nothing: anyone holding the unlocked phone would turn it off and
/// connect. The exception is a device that can no longer ask at all — the
/// screen lock was removed since — where demanding a check that cannot happen
/// would strand the user behind their own lock. Then turning it off is allowed,
/// which gives nothing away: with no screen lock, the vault's prompt could not
/// have been satisfied by the owner either.
class AppLockController {
  AppLockController(this._ref);

  final Ref _ref;

  Future<AppLockChange> setEnabled(
    bool enabled, {
    required String reason,
  }) async {
    final current = _ref.read(settingsControllerProvider).requireUnlock;
    if (current == enabled) {
      return enabled ? AppLockChange.enabled : AppLockChange.disabled;
    }

    final authenticator = _ref.read(deviceAuthenticatorProvider);
    final available = await authenticator.isAvailable();

    if (enabled && !available) return AppLockChange.unavailable;

    if (available) {
      final result = await authenticator.authenticate(reason);
      final mayProceed =
          result == DeviceAuthResult.success ||
          // Turning off on a device that turned out unable to ask: see the
          // class comment.
          (!enabled && result == DeviceAuthResult.unavailable);
      if (!mayProceed) return _changeFor(result);
    }

    _ref.read(settingsControllerProvider.notifier).setRequireUnlock(enabled);
    return enabled ? AppLockChange.enabled : AppLockChange.disabled;
  }

  static AppLockChange _changeFor(DeviceAuthResult result) => switch (result) {
    DeviceAuthResult.success => throw StateError('success is not a refusal'),
    DeviceAuthResult.cancelled => AppLockChange.cancelled,
    DeviceAuthResult.unavailable => AppLockChange.unavailable,
    DeviceAuthResult.lockedOut => AppLockChange.lockedOut,
    DeviceAuthResult.failed => AppLockChange.failed,
  };
}

final appLockControllerProvider = Provider<AppLockController>(
  AppLockController.new,
);

/// Strings for code that runs with no [BuildContext] — the vault's prompt is
/// raised from inside a connection attempt, far from any widget.
///
/// Follows the language chosen in Settings, then the device's, then English.
AppLocalizations appLocalizationsFor(String? localeCode) {
  final supported = {
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  };
  final wanted = localeCode ?? PlatformDispatcher.instance.locale.languageCode;
  return lookupAppLocalizations(
    Locale(supported.contains(wanted) ? wanted : 'en'),
  );
}
