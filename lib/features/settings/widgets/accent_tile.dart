import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/accent.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Accent picker, shown inline as a row of swatches.
///
/// Inline rather than behind a dialog: the whole point of an accent is that
/// you see the effect, and tapping a swatch repaints the app underneath it.
class AccentTile extends ConsumerWidget {
  const AccentTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final brightness = Theme.of(context).brightness;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(PiconsRegular.palette),
          title: Text(l10n.settingsAccent),
          subtitle: Text(accentLabel(l10n, settings.accentId)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.lg,
          ),
          child: Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: [
              for (final accent in Accents.all)
                _Swatch(
                  color: accent.forBrightness(brightness),
                  label: accentLabel(l10n, accent.id),
                  selected: accent.id == settings.accentId,
                  onTap: () => ref
                      .read(settingsControllerProvider.notifier)
                      .setAccent(accent.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        // 44 is the smallest comfortable touch target; the painted circle is
        // smaller, so the swatches read as light without being hard to hit.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.fast,
              width: selected ? 32 : 28,
              height: selected ? 32 : 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.onSurface : Colors.transparent,
                  width: BorderWidths.emphasis,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 16, color: _onColor(color))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Black or white, whichever reads on [background].
Color _onColor(Color background) =>
    background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

/// Localised name for an accent id.
String accentLabel(AppLocalizations l10n, String id) => switch (id) {
  'indigo' => l10n.accentIndigo,
  'teal' => l10n.accentTeal,
  'forest' => l10n.accentForest,
  'amber' => l10n.accentAmber,
  'coral' => l10n.accentCoral,
  'rose' => l10n.accentRose,
  'mauve' => l10n.accentMauve,
  'slate' => l10n.accentSlate,
  _ => Accents.byId(id).name,
};
