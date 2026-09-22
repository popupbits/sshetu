import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Whether new terminal tabs keep their shell running on the server, in tmux,
/// so a dropped connection reattaches instead of starting over.
class KeepSessionsTile extends ConsumerWidget {
  const KeepSessionsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final keep = ref.watch(
      settingsControllerProvider.select((s) => s.keepSessionsOnServer),
    );

    return SwitchListTile(
      secondary: const Icon(PiconsRegular.stack),
      title: Text(l10n.settingsKeepSessions),
      subtitle: Text(l10n.settingsKeepSessionsBody),
      isThreeLine: true,
      value: keep,
      onChanged: ref
          .read(settingsControllerProvider.notifier)
          .setKeepSessionsOnServer,
    );
  }
}
