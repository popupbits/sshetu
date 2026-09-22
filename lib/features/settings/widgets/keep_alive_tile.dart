import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Android only: whether a foreground service keeps connections open while
/// the app is in the background. `tiles.dart` shows it only where that
/// service exists.
class KeepAliveTile extends ConsumerWidget {
  const KeepAliveTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(
      settingsControllerProvider.select((s) => s.keepAliveInBackground),
    );

    return SwitchListTile(
      secondary: const Icon(PiconsRegular.plugsConnected),
      title: Text(l10n.settingsKeepAlive),
      subtitle: Text(l10n.settingsKeepAliveBody),
      value: enabled,
      onChanged: ref
          .read(settingsControllerProvider.notifier)
          .setKeepAliveInBackground,
    );
  }
}
