import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/features/files/file_browser_controller.dart';
import 'package:sshetu/features/files/widgets/remote_pane.dart';
import 'package:sshetu/l10n/app_localizations.dart';

import 'fake_sftp_service.dart';

/// `RemotePane` renders three visibly different things for three different
/// reasons a listing can have nothing useful to show — collapsing them into
/// one generic error (or worse, one blank screen) is the exact regression
/// this guards against, since "permission denied" and "empty folder" used to
/// look identical before `SftpException.kind` existed.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  late Directory localRoot;

  setUp(() async {
    localRoot = await Directory.systemTemp.createTemp('pane_states_test');
  });

  tearDown(() {
    if (localRoot.existsSync()) localRoot.deleteSync(recursive: true);
  });

  testWidgets('an empty directory shows the empty-folder state', (
    tester,
  ) async {
    final sftp = FakeSftpService(directories: {'/': []});
    final controller = FileBrowserController(
      sftp: sftp,
      localRoot: localRoot.path,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(wrap(RemotePane(controller: controller)));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.filesEmptyTitle), findsOneWidget);
    expect(find.text(l10n.filesPermissionDeniedTitle), findsNothing);
    expect(find.text(l10n.filesNotFoundTitle), findsNothing);
  });

  testWidgets(
    'a directory this account cannot read shows the permission-denied state',
    (tester) async {
      final sftp = FakeSftpService()
        ..failListPath = '/'
        ..failListKind = SftpFailureKind.permissionDenied;
      final controller = FileBrowserController(
        sftp: sftp,
        localRoot: localRoot.path,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(wrap(RemotePane(controller: controller)));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.filesPermissionDeniedTitle), findsOneWidget);
      // Neither of the other two states must also render.
      expect(find.text(l10n.filesEmptyTitle), findsNothing);
      expect(find.text(l10n.filesNotFoundTitle), findsNothing);
    },
  );

  testWidgets('a directory that no longer exists shows the not-found state', (
    tester,
  ) async {
    final sftp = FakeSftpService()
      ..failListPath = '/'
      ..failListKind = SftpFailureKind.notFound;
    final controller = FileBrowserController(
      sftp: sftp,
      localRoot: localRoot.path,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(wrap(RemotePane(controller: controller)));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.filesNotFoundTitle), findsOneWidget);
    expect(find.text(l10n.filesEmptyTitle), findsNothing);
    expect(find.text(l10n.filesPermissionDeniedTitle), findsNothing);
  });

  testWidgets(
    'an SftpException with kind other still falls back to the generic error view',
    (tester) async {
      // The bug this guards against: a status code with no dedicated kind
      // (SSH_FX_FAILURE and friends) must still show *something* actionable
      // rather than silently rendering as if the folder were merely empty.
      final sftp = FakeSftpService()
        ..failListPath = '/'
        ..failListKind = SftpFailureKind.other;
      final controller = FileBrowserController(
        sftp: sftp,
        localRoot: localRoot.path,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(wrap(RemotePane(controller: controller)));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.filesEmptyTitle), findsNothing);
      expect(find.text(l10n.filesPermissionDeniedTitle), findsNothing);
      expect(find.text(l10n.filesNotFoundTitle), findsNothing);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    },
  );
}
