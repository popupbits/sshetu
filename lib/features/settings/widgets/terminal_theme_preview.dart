import 'package:material_ui/material_ui.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// A few lines of a terminal, drawn in [preset]'s colours.
///
/// A prompt, an `ls` with a directory, a file and an executable, and an
/// error — the colours people actually look at, so choosing a theme is
/// choosing what their own session will look like rather than reading a
/// palette. Drawn with plain text rather than a live xterm2 view: nine live
/// terminals in a grid would be nine buffers for a thumbnail.
///
/// The palette's colours are used directly on purpose. They are the data
/// being previewed, not app chrome, so they must not follow the app theme.
class TerminalThemePreview extends StatelessWidget {
  const TerminalThemePreview({required this.preset, super.key});

  final TerminalThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final p = preset.paletteFor(theme.colorScheme);
    final red = p.ansi[1];
    final green = p.ansi[2];
    final blue = p.ansi[4];
    final base = Mono.apply(theme.textTheme.bodySmall)
        .copyWith(color: p.foreground, height: 1.4);
    final bold = base.copyWith(fontWeight: FontWeight.w700);

    List<InlineSpan> prompt() => [
      TextSpan(
        text: l10n.terminalPreviewUser,
        style: bold.copyWith(color: green),
      ),
      const TextSpan(text: ':'),
      TextSpan(
        text: '~',
        style: bold.copyWith(color: blue),
      ),
      const TextSpan(text: r'$ '),
    ];

    Widget line(List<InlineSpan> spans) => Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              line([...prompt(), TextSpan(text: l10n.terminalPreviewCommand)]),
              line([
                TextSpan(
                  text: l10n.terminalPreviewDirectory,
                  style: bold.copyWith(color: blue),
                ),
                const TextSpan(text: '  '),
                TextSpan(text: l10n.terminalPreviewFile),
                const TextSpan(text: '  '),
                TextSpan(
                  text: l10n.terminalPreviewScript,
                  style: bold.copyWith(color: green),
                ),
              ]),
              line([
                TextSpan(
                  text: l10n.terminalPreviewError,
                  style: base.copyWith(color: red),
                ),
              ]),
              line([
                ...prompt(),
                // The cursor, as a block of the preset's cursor colour.
                // A box rather than a styled space: a trailing space's
                // background is not painted. Sized from the text, so it is
                // one cell wide at whatever size the text is.
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Builder(
                    builder: (context) {
                      final size = MediaQuery.textScalerOf(context)
                          .scale(base.fontSize ?? 12);
                      return Container(
                        width: size * 0.6,
                        height: size * 1.2,
                        color: p.cursor,
                      );
                    },
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// A preset at a glance: its background with four of its colours on it.
///
/// For places with no room for [TerminalThemePreview] — a settings row, a
/// dropdown item.
class TerminalThemeSwatch extends StatelessWidget {
  const TerminalThemeSwatch({required this.preset, super.key});

  final TerminalThemePreset preset;

  static const double _width = 44;
  static const double _height = 24;
  static const double _dot = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = preset.paletteFor(scheme);
    return ExcludeSemantics(
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(Radii.xs),
          // A hairline, so a preset whose background matches the surface
          // behind it still reads as a swatch.
          border: Border.all(
            color: scheme.outlineVariant,
            width: BorderWidths.hairline,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final color in [p.foreground, p.ansi[1], p.ansi[2], p.ansi[4]])
              Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
