import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A request for the Settings screen to bring one section into view.
///
/// Published by whatever navigates to Settings on someone's behalf — the
/// command palette — and answered by the screen. [serial] makes asking for the
/// same section twice two requests, so the second still scrolls.
@immutable
class SettingsScrollRequest {
  const SettingsScrollRequest(this.sectionTitle, this.serial);

  /// The section's title, as [settingsSections] names it.
  final String sectionTitle;
  final int serial;
}

final settingsScrollRequestProvider =
    NotifierProvider<SettingsScrollRequests, SettingsScrollRequest?>(
      SettingsScrollRequests.new,
    );

class SettingsScrollRequests extends Notifier<SettingsScrollRequest?> {
  var _serial = 0;

  @override
  SettingsScrollRequest? build() => null;

  void request(String sectionTitle) =>
      state = SettingsScrollRequest(sectionTitle, ++_serial);

  /// Marks the request answered, so a screen built later does not jump.
  void clear() => state = null;
}
