/// The face the interface is drawn in.
///
/// Inter, bundled in the app rather than fetched. This used to come from
/// `google_fonts`, which downloads a face from Google's CDN the first time it
/// is drawn: on a first launch with no network the whole interface fell back
/// to the platform's default face, and on every other first launch the app
/// made a request to a third party before the user had done anything. For an
/// app whose promise is that nothing leaves the device, the second was the
/// worse of the two.
///
/// Four static weights ship — 400, 500, 600, 700 — which is what the
/// interface asks for. The name must match the `family:` in pubspec.yaml.
abstract final class UiFont {
  static const String family = 'Inter';

  /// The SIL OFL text, which the licence asks to travel with the font.
  /// Registered on the licences page by `RegisterFontLicenses`.
  static const String licenseAsset = 'assets/fonts/inter/OFL.txt';
}
