import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/host_os.dart';

/// A small, neutral mark for the OS a host runs.
///
/// Secondary to the host's monogram, so it is small and in the neutral
/// container colours — never a brand's own colour. Families picons draws
/// (Linux, macOS, Windows) get that glyph; distributions get a short text
/// code in a pill instead of a logo, because shipping their logos is theirs to
/// allow, not ours to assume. Unknown draws nothing: a question mark on every
/// host never connected to would be noise.
class OsBadge extends StatelessWidget {
  const OsBadge({required this.info, this.size = 14, super.key});

  final HostOsInfo info;
  final double size;

  /// Short codes for the text pill. Abbreviations of proper names, the same
  /// in every language, like the monogram — not translatable copy.
  static const codes = <OsFamily, String>{
    OsFamily.ubuntu: 'Ub',
    OsFamily.debian: 'De',
    OsFamily.fedora: 'Fe',
    OsFamily.rhel: 'RH',
    OsFamily.arch: 'Ar',
    OsFamily.alpine: 'Al',
    OsFamily.opensuse: 'SU',
    OsFamily.freebsd: 'BSD',
  };

  static IconData? glyphFor(OsFamily family) => switch (family) {
    OsFamily.macos => PiconsRegular.appleLogo,
    OsFamily.windows => PiconsRegular.windowsLogo,
    OsFamily.linux => PiconsRegular.linuxLogo,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    if (info.family == OsFamily.unknown) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final tooltip = info.prettyName ?? l10n.osFamilyName(info.family.name);
    final glyph = glyphFor(info.family);

    final Widget mark = glyph != null
        ? Icon(glyph, size: size, color: scheme.onSurfaceVariant)
        : Container(
            height: size,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              codes[info.family] ?? '?',
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: size * 0.62,
                height: 1,
                fontWeight: FontWeight.w700,
                color: scheme.onSecondaryContainer,
              ),
            ),
          );

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        child: ExcludeSemantics(child: mark),
      ),
    );
  }
}
