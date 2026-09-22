import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/terminal_theme_presets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import 'terminal_theme_preview.dart';

/// Asks for a terminal theme, showing each one rendered.
///
/// A sheet on a phone, where it can use the height; a dialog on a desktop,
/// where a sheet would be a strip across the bottom of a wide window. Returns
/// the chosen preset's id, or null if dismissed.
Future<String?> showTerminalThemePicker(
  BuildContext context, {
  required String selectedId,
}) {
  // Popped through the route's own context: a dialog goes on the root
  // navigator, and the caller's may be a nested one.
  Widget picker(BuildContext routeContext) => TerminalThemePicker(
    selectedId: selectedId,
    onSelected: (id) => Navigator.of(routeContext).pop(id),
  );
  if (context.usesSoftwareKeyboard || context.isCompact) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          FractionallySizedBox(heightFactor: 0.85, child: picker(context)),
    );
  }
  return showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: picker(context),
      ),
    ),
  );
}

/// The grid of presets. Separate from [showTerminalThemePicker] so it can be
/// tested at a width without opening a route.
class TerminalThemePicker extends StatelessWidget {
  const TerminalThemePicker({
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  /// Wide enough for the preview's longest line at the small mono size; the
  /// grid fits as many columns of this as the width allows — one on a narrow
  /// phone, two on most, three or four in a desktop dialog.
  static const double _maxTileWidth = 240;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.lg,
            Spacing.xl,
            Spacing.sm,
          ),
          child: Text(
            l10n.settingsTerminalTheme,
            style: theme.textTheme.titleLarge,
          ),
        ),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.xl,
            ),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: _maxTileWidth,
              mainAxisSpacing: Spacing.md,
              crossAxisSpacing: Spacing.md,
              // Fixed height rather than an aspect ratio: the preview is a
              // fixed number of text lines, and a tile that grows with its
              // width only adds empty background. Scaled with the text, since
              // every line in the tile is text.
              mainAxisExtent: MediaQuery.textScalerOf(context)
                  .scale(_TerminalThemeCard.height),
            ),
            itemCount: TerminalThemePresets.all.length,
            itemBuilder: (context, index) {
              final preset = TerminalThemePresets.all[index];
              return _TerminalThemeCard(
                preset: preset,
                selected: preset.id == selectedId,
                onTap: () => onSelected(preset.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TerminalThemeCard extends StatelessWidget {
  const _TerminalThemeCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final TerminalThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  /// Preview (four lines at the small size plus padding) and the label row.
  static const double height = 160;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final palette = preset.palette;
    final description = palette == null
        ? l10n.terminalThemeAdaptive
        : palette.isLight
        ? l10n.terminalThemeFixedLight
        : l10n.terminalThemeFixedDark;

    return Semantics(
      button: true,
      selected: selected,
      label: preset.name,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? BorderWidths.emphasis : BorderWidths.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: TerminalThemePreview(preset: preset)),
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.name,
                            style: theme.textTheme.labelLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(PiconsRegular.checkCircle, color: scheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
