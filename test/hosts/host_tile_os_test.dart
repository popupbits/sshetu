import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/hosts/hosts_controller.dart';
import 'package:sshetu/features/hosts/hosts_screen.dart';
import 'package:sshetu/features/server_info/domain/host_os.dart';
import 'package:sshetu/features/server_info/host_os_controller.dart';
import 'package:sshetu/features/server_info/widgets/os_badge.dart';
import 'package:sshetu/l10n/app_localizations.dart';

class _PresetOs extends HostOsController {
  _PresetOs(this.preset);

  final Map<String, HostOsInfo> preset;

  @override
  Map<String, HostOsInfo> build() => preset;
}

/// The OS mark on a host row: secondary to the monogram, absent until known.
void main() {
  final now = DateTime.utc(2026, 1, 1);

  SshHost host(String label) => SshHost(
    id: label,
    label: label,
    hostname: '$label.example.com',
    username: 'root',
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pump(
    WidgetTester tester,
    Map<String, HostOsInfo> os, {
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostsProvider.overrideWith(
            (ref) => [host('web'), host('mac'), host('fresh'), host('box')],
          ),
          hostOsProvider.overrideWith(() => _PresetOs(os)),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(body: HostsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(360, 740), Size(1280, 800)]) {
    testWidgets('marks known hosts only, at ${size.width.toInt()}', (
      tester,
    ) async {
      await pump(tester, const {
        'web': HostOsInfo(
          family: OsFamily.ubuntu,
          prettyName: 'Ubuntu 24.04.1 LTS',
        ),
        'mac': HostOsInfo(family: OsFamily.macos, prettyName: 'macOS 14.5'),
        'box': HostOsInfo(family: OsFamily.unknown),
      }, size: size);

      // Two marks drawn: Ubuntu (text pill) and macOS (glyph). An unknown
      // answer and an undetected host draw nothing.
      final badges = tester.widgetList<OsBadge>(
        find.byKey(const Key('hostTile.os')),
      );
      expect(badges, hasLength(3));
      expect(find.text('Ub'), findsOneWidget);
      expect(find.byIcon(PiconsRegular.appleLogo), findsOneWidget);
      expect(find.byTooltip('Ubuntu 24.04.1 LTS'), findsOneWidget);
      expect(find.byTooltip('macOS 14.5'), findsOneWidget);
      // The monogram stays.
      expect(find.text(host('web').monogram), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without a pretty name the tooltip names the family', (
    tester,
  ) async {
    await pump(tester, const {
      'web': HostOsInfo(family: OsFamily.rhel),
    }, size: const Size(800, 600));
    expect(find.text('RH'), findsOneWidget);
    expect(find.byTooltip('Red Hat family'), findsOneWidget);
  });
}
