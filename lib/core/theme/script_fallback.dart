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
/// Devanagari face, so bundling one would add weight for nothing, and
/// google_fonts would fetch it over the network — the same failure the
/// terminal faces avoid (see terminal_fonts.dart). A name that is not
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
