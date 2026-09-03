import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../util/launcher.dart';
import '../../l10n/app_localizations.dart';
import 'app_update_service.dart';

/// Drives Play's *flexible* update flow and reports it through a snackbar.
///
/// Flexible rather than immediate: an immediate update blocks behind a
/// full-screen Play dialog until it finishes, which is a poor trade for a user
/// who opened the app to do something.
///
/// The flow has more states than it first appears, and each one here was a bug
/// somewhere before it was a branch:
///
///  * **Downloaded in a previous session.** The user accepted, the app was
///    killed, Play finished in the background. Offering a fresh download would
///    re-download an update already on disk — offer *Install* instead.
///  * **`developerTriggeredUpdateInProgress`.** Play refuses to re-show the
///    consent sheet once a developer-triggered update is in progress. Resume
///    only if the download is genuinely alive; awaiting a dead one hangs
///    forever, so a dead session gets a recovery notice pointing at the Store.
///  * **A download that never finishes.** Bounded by [_flexibleTimeout] so the
///    await resolves to "stuck" rather than never resolving.
///  * **Completion arriving on resume.** Play often reports `downloaded` only
///    after the next resume, so the check runs again then — guarded by
///    [_noticeShown] so the two paths cannot stack duplicate snackbars.
class UpdateListener extends ConsumerStatefulWidget {
  const UpdateListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdateListener> createState() => _UpdateListenerState();
}

class _UpdateListenerState extends ConsumerState<UpdateListener> {
  AppLifecycleListener? _lifecycle;

  /// Latches once any update snackbar has shown this session.
  bool _noticeShown = false;

  /// Play finishes in seconds on a working network. Five minutes means the
  /// download is effectively dead — the service was killed, or the network
  /// went away mid-transfer.
  static const Duration _flexibleTimeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    // After the first frame: the messenger has to exist before we can use it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_checkOnStart()),
    );
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _onResume() {
    if (!_noticeShown) unawaited(_pollForDownloaded());
  }

  Future<void> _checkOnStart() async {
    final service = ref.read(appUpdateServiceProvider);
    final info = await service.checkForUpdate();
    if (info == null) return;

    if (info.installStatus == InstallStatus.downloaded) {
      _showInstallReady(service);
      return;
    }

    if (info.updateAvailability ==
        UpdateAvailability.developerTriggeredUpdateInProgress) {
      if (info.installStatus == InstallStatus.downloading) {
        _handleResult(service, await _awaitFlexible(service));
      } else {
        _showStuck();
      }
      return;
    }

    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
    if (!info.flexibleUpdateAllowed) return;
    _handleResult(service, await _awaitFlexible(service));
  }

  Future<void> _pollForDownloaded() async {
    final service = ref.read(appUpdateServiceProvider);
    final info = await service.checkForUpdate();
    if (info == null || info.installStatus != InstallStatus.downloaded) return;
    _showInstallReady(service);
  }

  Future<AppUpdateResult?> _awaitFlexible(AppUpdateService service) async {
    try {
      return await service.startFlexibleUpdate().timeout(_flexibleTimeout);
    } on TimeoutException {
      return null;
    }
  }

  void _handleResult(AppUpdateService service, AppUpdateResult? result) {
    if (result == AppUpdateResult.success) {
      _showInstallReady(service);
      return;
    }
    // The user declining is a complete, correct outcome — say nothing.
    if (result == AppUpdateResult.userDeniedUpdate) return;
    _showStuck();
  }

  void _showInstallReady(AppUpdateService service) {
    final messenger = rootMessengerKey.currentState;
    if (_noticeShown || messenger == null || !mounted) return;
    _noticeShown = true;
    final l10n = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.updateReadyTitle),
        // Persistent: the install is worth surfacing until acted on, and the
        // close icon lets the user dismiss it.
        duration: const Duration(days: 1),
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.updateRestart,
          onPressed: () => unawaited(service.completeFlexibleUpdate()),
        ),
      ),
    );
  }

  void _showStuck() {
    final messenger = rootMessengerKey.currentState;
    if (_noticeShown || messenger == null || !mounted) return;
    _noticeShown = true;
    final l10n = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.updateStuck),
        duration: const Duration(days: 1),
        showCloseIcon: true,
        action: SnackBarAction(
          label: l10n.updateOpenStore,
          onPressed: () => unawaited(Launcher.openStoreListing()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
