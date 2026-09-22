import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/secrets/app_lock.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';

/// The switch for the credential lock.
///
/// Flipping it asks the device first — see [AppLockController] — so the switch
/// only moves once the system prompt has succeeded, and it is disabled while
/// that prompt is up so a second tap cannot raise a second one.
class AppLockTile extends ConsumerStatefulWidget {
  const AppLockTile({super.key});

  @override
  ConsumerState<AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends ConsumerState<AppLockTile> {
  bool _busy = false;

  Future<void> _toggle(bool enabled) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final AppLockChange change;
    try {
      change = await ref
          .read(appLockControllerProvider)
          .setEnabled(
            enabled,
            reason: enabled
                ? l10n.appLockEnableReason
                : l10n.appLockDisableReason,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    final message = switch (change) {
      AppLockChange.enabled || AppLockChange.disabled => null,
      AppLockChange.cancelled => l10n.settingsAppLockCancelled,
      AppLockChange.unavailable => l10n.settingsAppLockUnavailable,
      AppLockChange.lockedOut => l10n.settingsAppLockLockedOut,
      AppLockChange.failed => l10n.settingsAppLockFailed,
    };
    if (message != null) {
      context.toast(message, isError: change != AppLockChange.cancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(
      settingsControllerProvider.select((s) => s.requireUnlock),
    );

    return SwitchListTile(
      secondary: const Icon(PiconsRegular.fingerprint),
      title: Text(l10n.settingsAppLock),
      subtitle: Text(l10n.settingsAppLockBody),
      value: enabled,
      onChanged: _busy ? null : _toggle,
    );
  }
}
