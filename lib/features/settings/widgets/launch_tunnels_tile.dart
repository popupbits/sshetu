import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../l10n/app_localizations.dart';
import '../../tunnels/launch_auto_start.dart';

/// Whether auto-start tunnels start when the app opens, rather than when a
/// terminal to their host connects. Off by default; see
/// [LaunchAutoStartSetting].
class LaunchTunnelsTile extends ConsumerWidget {
  const LaunchTunnelsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile(
      key: const Key('settings.startTunnelsAtLaunch'),
      secondary: const Icon(PiconsRegular.arrowsLeftRight),
      title: Text(l10n.settingsStartTunnelsAtLaunch),
      subtitle: Text(l10n.settingsStartTunnelsAtLaunchBody),
      isThreeLine: true,
      value: ref.watch(launchAutoStartSettingProvider),
      onChanged: ref.read(launchAutoStartSettingProvider.notifier).set,
    );
  }
}
