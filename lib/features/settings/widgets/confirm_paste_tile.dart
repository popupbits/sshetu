import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Whether a paste that would run a command asks first.
///
/// The paste dialog's "Don't ask again" turns this off; this row is the way
/// back, and the place to find the setting without having pasted anything.
class ConfirmPasteTile extends ConsumerWidget {
  const ConfirmPasteTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final confirm = ref.watch(
      settingsControllerProvider.select((s) => s.confirmMultilinePaste),
    );

    return SwitchListTile(
      secondary: const Icon(PiconsRegular.clipboardText),
      title: Text(l10n.settingsConfirmPaste),
      subtitle: Text(l10n.settingsConfirmPasteBody),
      value: confirm,
      onChanged: ref
          .read(settingsControllerProvider.notifier)
          .setConfirmMultilinePaste,
    );
  }
}
