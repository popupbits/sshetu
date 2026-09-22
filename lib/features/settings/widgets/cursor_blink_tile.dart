import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Whether the terminal cursor blinks unless a program says otherwise.
class CursorBlinkTile extends ConsumerWidget {
  const CursorBlinkTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blink = ref.watch(
      settingsControllerProvider.select((s) => s.cursorBlink),
    );

    return SwitchListTile(
      secondary: const Icon(PiconsRegular.lightning),
      title: Text(l10n.settingsCursorBlink),
      subtitle: Text(l10n.settingsCursorBlinkBody),
      value: blink,
      onChanged: ref.read(settingsControllerProvider.notifier).setCursorBlink,
    );
  }
}
