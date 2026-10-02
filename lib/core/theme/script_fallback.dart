/// Faces that cover scripts the primary fonts do not.
///
/// Inter (the UI face) and every bundled terminal face are Latin-only, and the
/// app ships a Nepali translation, so Devanagari has to come from somewhere
/// else. Flutter does fall back to a system face for a missing glyph on every
/// native platform, but *which* face it lands on is the platform's guess —
/// naming them makes it the face each platform ships for Devanagari, and makes
/// the intent visible where a missing glyph would otherwise be a mystery.
///
/// **Named, not bundled.** Every platform SSHetu targets already carries a
/// Devanagari face, and one costs about a megabyte — weight for nothing,
/// when the alternative is a name the platform resolves for free. Fetching
/// one instead is not an option: nothing in this app reaches the network for
/// a typeface (see terminal_fonts.dart and ui_font.dart). A name that is not
/// installed is skipped, so listing faces for every platform is harmless.
///
/// These are only consulted for a glyph the primary face lacks: Latin text is
/// never drawn from them.
abstract final class ScriptFallback {
  static const List<String> devanagari = [
    'Noto Sans Devanagari', // Android, and Linux with fonts-noto
    'Kohinoor Devanagari', // iOS 9+, macOS 10.11+
    'Devanagari Sangam MN', // iOS, macOS
    'Nirmala UI', // Windows 8+
    'Mangal', // Windows, older
    'Lohit Devanagari', // Linux (Fedora and others)
  ];
}
