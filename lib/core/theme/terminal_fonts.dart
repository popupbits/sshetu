import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import '../bootstrap.dart';
import 'terminal_theme.dart';
import 'ui_font.dart';

/// A face the terminal grid can be drawn in.
///
/// **Bundled, never fetched.** Every face but the system one ships inside the
/// app as a font asset (`assets/fonts/`, declared under `flutter: fonts:` in
/// pubspec.yaml), as the UI face does — see ui_font.dart. A font package
/// that fetches from a CDN downloads a face the first time it is asked for
/// and caches it; until that download finishes —
/// or forever, on a machine that is offline, air-gapped or behind a proxy —
/// text is drawn in the fallback instead. An SSH client is exactly the app
/// people open on a network that is not working, and a terminal whose columns
/// change width depending on whether a CDN was reachable is a bug. So these
/// are plain `fontFamily` names resolved from the app bundle, with no network
/// path at all. Regular and Bold of each are bundled: the grid draws bold
/// text, and a synthesised bold smears.
@immutable
class TerminalFont {
  const TerminalFont({
    required this.id,
    required this.family,
    this.licenseAsset,
  });

  /// Stored in settings. Never change one.
  final String id;

  /// The family as declared in pubspec.yaml; null for the system monospace,
  /// which is decided per platform by [Mono.family].
  final String? family;

  /// The SIL OFL text shipped beside a bundled face, which its licence
  /// requires to travel with it.
  final String? licenseAsset;

  bool get isSystem => family == null;

  /// The family xterm2 is handed.
  String get resolvedFamily => family ?? Mono.family;

  /// What is tried when a glyph is missing from the chosen face — box drawing
  /// in an older face, a CJK character, an emoji. The platform monospace comes
  /// first, so a gap is filled by something still monospaced.
  List<String> get fallback => [if (!isSystem) Mono.family, ...Mono.fallback];

  /// The grid's text style at [fontSize].
  ///
  /// Ligatures are off, and not by this code: xterm2's `TerminalStyle` applies
  /// `liga`, `calt`, `clig`, `dlig` and `hlig` disabled to every cell it lays
  /// out — which matters for Fira Code, whose `=>` and `!=` would otherwise be
  /// drawn as one glyph spanning two cells the remote program addressed
  /// separately. `test/core/theme/terminal_fonts_test.dart` pins that.
  TerminalStyle style(double fontSize) => TerminalStyle(
    fontFamily: resolvedFamily,
    fontFamilyFallback: fallback,
    fontSize: fontSize,
  );
}

/// The faces on offer, and how a stored id becomes one.
abstract final class TerminalFonts {
  static const String defaultId = 'system';

  /// The platform's own terminal face — Cascadia Mono, SF Mono, DejaVu Sans
  /// Mono or Roboto Mono. The default: it is what the user's other terminals
  /// already look like, and it costs nothing.
  static const system = TerminalFont(id: defaultId, family: null);

  /// https://github.com/JetBrains/JetBrainsMono — OFL 1.1.
  static const jetBrainsMono = TerminalFont(
    id: 'jetbrains-mono',
    family: 'JetBrains Mono',
    licenseAsset: 'assets/fonts/jetbrains_mono/OFL.txt',
  );

  /// https://github.com/tonsky/FiraCode (6.2) — OFL 1.1. Its ligatures are
  /// disabled; see [TerminalFont.style].
  static const firaCode = TerminalFont(
    id: 'fira-code',
    family: 'Fira Code',
    licenseAsset: 'assets/fonts/fira_code/OFL.txt',
  );

  /// https://github.com/adobe-fonts/source-code-pro — OFL 1.1.
  static const sourceCodePro = TerminalFont(
    id: 'source-code-pro',
    family: 'Source Code Pro',
    licenseAsset: 'assets/fonts/source_code_pro/OFL.txt',
  );

  /// https://github.com/IBM/plex — OFL 1.1.
  static const ibmPlexMono = TerminalFont(
    id: 'ibm-plex-mono',
    family: 'IBM Plex Mono',
    licenseAsset: 'assets/fonts/ibm_plex_mono/OFL.txt',
  );

  static const List<TerminalFont> all = [
    system,
    jetBrainsMono,
    firaCode,
    sourceCodePro,
    ibmPlexMono,
  ];

  /// The face for [id]; the system monospace for null or anything unknown.
  static TerminalFont byId(String? id) =>
      all.firstWhere((f) => f.id == id, orElse: () => system);
}

/// Puts every bundled face's licence on the licences page — the UI face as
/// well as the terminal ones.
///
/// The SIL OFL asks that the licence travel with the font. The text is read
/// lazily — only when someone opens that page — so this costs nothing at
/// startup.
class RegisterFontLicenses extends BootstrapStep {
  const RegisterFontLicenses();

  @override
  String get name => 'font licences';

  @override
  Future<void> run() async {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        UiFont.family,
      ], await rootBundle.loadString(UiFont.licenseAsset));
      for (final font in TerminalFonts.all) {
        final asset = font.licenseAsset;
        final family = font.family;
        if (asset == null || family == null) continue;
        yield LicenseEntryWithLineBreaks([
          family,
        ], await rootBundle.loadString(asset));
      }
    });
  }
}
