import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sshetu/core/settings/settings_controller.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';
import 'package:sshetu/core/ssh/ssh_target.dart';
import 'package:sshetu/core/terminal/terminal_session.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/sessions/session_manager.dart';
import 'package:sshetu/features/sessions/sessions_palette.dart';
import 'package:sshetu/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('en'));

  TerminalSession tab(String id, String title, String host) => TerminalSession(
    id: id,
    title: title,
    hostId: 'host-$id',
    connection: SshConnection(
      target: SshTarget(hostname: host, username: 'deploy'),
      verifierFactory: (_, _) => throw UnimplementedError(),
    ),
  );

  Future<ProviderContainer> build() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('no tabs, no items — not even find', () async {
    final container = await build();
    expect(container.read(sessionPaletteItemsProvider(l10n)), isEmpty);
  });

  test('one item per open tab, then find', () async {
    final container = await build();
    container.read(sessionManagerProvider.notifier)
      ..adopt(tab('t1', 'web-01', 'web-01.example.com'))
      ..adopt(tab('t2', 'database', 'db.internal'));

    final items = container.read(sessionPaletteItemsProvider(l10n));
    expect(
      [for (final i in items) i.id],
      ['session:t1', 'session:t2', 'action:findInTerminal'],
    );
    expect(items.first.title, 'web-01');
    expect(items.first.subtitle, 'deploy@web-01.example.com');
    expect(items.first.category, PaletteCategory.session);
    expect(items.first.primary.id, 'switch');
  });

  test('the list follows tabs closing', () async {
    final container = await build();
    final manager = container.read(sessionManagerProvider.notifier)
      ..adopt(tab('t1', 'web-01', 'web-01.example.com'));
    expect(container.read(sessionPaletteItemsProvider(l10n)), hasLength(2));
    manager.close('t1');
    expect(container.read(sessionPaletteItemsProvider(l10n)), isEmpty);
  });
}
