import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/router/navigation.dart';
import '../../../core/router/routes.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../sessions/workspace_pages.dart';
import 'receive_screen.dart';
import 'send_screen.dart';

/// Opens a transfer where it belongs on this form factor.
///
/// On a desktop that is a **tab in the workspace**, beside the terminals. The
/// full-screen route was wrong there: moving a configuration to a phone is
/// something you do next to a shell, not instead of it, and taking the whole
/// window away to show a QR code loses the session someone was working in.
///
/// On a phone there is only ever one thing on screen, so it stays a page.
void openTransferSend(BuildContext context, WidgetRef ref) => _open(
  context,
  ref,
  id: 'transfer/send',
  title: AppLocalizations.of(context).transferSend,
  icon: PiconsRegular.qrCode,
  route: Routes.transferSend,
  builder: (_) => const TransferSendScreen(embedded: true),
);

void openTransferReceive(BuildContext context, WidgetRef ref) => _open(
  context,
  ref,
  id: 'transfer/receive',
  title: AppLocalizations.of(context).transferReceive,
  icon: PiconsRegular.downloadSimple,
  route: Routes.transferReceive,
  builder: (_) => const TransferReceiveScreen(embedded: true),
);

void _open(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String title,
  required IconData icon,
  required String route,
  required WidgetBuilder builder,
}) {
  if (!context.useRail) {
    context.pushTo(route);
    return;
  }
  ref
      .read(workspacePagesProvider.notifier)
      .open(WorkspacePage(id: id, title: title, icon: icon, builder: builder));
}
