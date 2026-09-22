import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Block, underline or bar. A program that asks for a shape of its own —
/// the insert mode of vim, for one — still gets it; this is what it returns
/// to afterwards.
class CursorShapeTile extends ConsumerWidget {
  const CursorShapeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shape = ref.watch(
      settingsControllerProvider.select((s) => s.cursorShape),
    );

    String label(TerminalCursorShape s) => switch (s) {
      TerminalCursorShape.block => l10n.cursorShapeBlock,
      TerminalCursorShape.underline => l10n.cursorShapeUnderline,
      TerminalCursorShape.bar => l10n.cursorShapeBar,
    };

    return ListTile(
      leading: const Icon(PiconsRegular.cursorText),
      title: Text(l10n.settingsCursorShape),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Spacing.sm),
        child: SegmentedButton<TerminalCursorShape>(
          showSelectedIcon: false,
          segments: [
            for (final s in TerminalCursorShape.values)
              ButtonSegment(value: s, label: Text(label(s))),
          ],
          selected: {shape},
          onSelectionChanged: (selection) => ref
              .read(settingsControllerProvider.notifier)
              .setCursorShape(selection.single),
        ),
      ),
    );
  }
}
