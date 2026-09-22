import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../sessions/open_screens.dart';
import '../domain/ssh_host.dart';

/// Shows a host's notes, read-only, with a way into the editor.
///
/// Selectable, because the commonest thing in a server note is something to
/// copy — a path, a port, a runbook link.
Future<void> showHostNotes(BuildContext context, WidgetRef ref, SshHost host) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(host.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxMessageWidth,
            ),
            child: SingleChildScrollView(
              child: SelectableText(host.notes?.trim() ?? ''),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openHostEditor(context, ref, hostId: host.id);
              },
              child: Text(l10n.hostsEdit),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionClose),
            ),
          ],
        );
      },
    );
