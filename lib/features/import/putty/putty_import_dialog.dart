import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/db/database.dart';
import '../../../core/error/error_logger.dart';
import '../../../core/providers.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../export/data/portable_export_store.dart';
import '../../export/portable_export_service.dart';
import '../../hosts/hosts_controller.dart';
import '../../tunnels/tunnels_controller.dart';
import 'putty_import.dart';
import 'putty_sessions.dart';

const XTypeGroup _regTypeGroup = XTypeGroup(
  label: 'Registry file',
  extensions: ['reg'],
);

/// Import from PuTTY.
///
/// On Windows, straight from this account's registry, with a `.reg` file as
/// the other way in; everywhere else (or with [fromFile]) from a `.reg` file
/// the user picks — how a Mac user brings over the sessions from their old
/// Windows machine.
Future<void> importPutty(
  BuildContext context,
  WidgetRef ref, {
  bool fromFile = false,
  PuttyRegistryReader? reader,
  PortableExportService? files,
}) async {
  final l10n = AppLocalizations.of(context);
  final PortableExportService picker =
      files ?? ref.read(portableExportServiceProvider);
  final existing = await ref.read(hostRepositoryProvider).all();
  if (!context.mounted) return;

  Future<({Uint8List bytes, String name})?> pickFile() =>
      picker.pick(_regTypeGroup);

  ({Uint8List bytes, String name})? source;
  try {
    if (!fromFile && PuttyRegistryReader.isSupported) {
      final bytes = await (reader ?? PuttyRegistryReader()).export();
      final found = bytes == null
          ? const <PuttyCandidate>[]
          : PuttyImport.candidates(bytes, existing);
      if (!context.mounted) return;
      if (found.isEmpty) {
        final choose = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(PiconsRegular.terminalWindow),
            title: Text(l10n.puttyNoneFoundTitle),
            content: Text(l10n.puttyNoneFoundBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.puttyChooseFile),
              ),
            ],
          ),
        );
        if (choose != true) return;
        source = await pickFile();
      } else {
        source = (bytes: bytes!, name: PuttyRegistryReader.registryKey);
      }
    } else {
      source = await pickFile();
    }
  } on Object catch (error, stackTrace) {
    ErrorLogger.instance.record(error, stackTrace, source: 'import-putty');
    if (context.mounted) {
      context.toast(l10n.puttyReadFailed('$error'), isError: true);
    }
    return;
  }

  while (source != null) {
    if (!context.mounted) return;
    final candidates = PuttyImport.candidates(source.bytes, existing);
    if (candidates.isEmpty) {
      context.toast(l10n.puttyNoneInFile, isError: true);
      return;
    }
    final choice = await showDialog<PuttyChoice>(
      context: context,
      builder: (_) =>
          PuttyImportDialog(candidates: candidates, source: source!.name),
    );
    if (choice == null || !context.mounted) return;
    if (choice.pickFile) {
      source = await pickFile();
      continue;
    }

    final changes = PuttyImport.changes(
      choice.sessions,
      fallbackUsername: localUsername(),
      now: DateTime.now().toUtc(),
    );
    try {
      await PortableExportStore.apply(ref.read(databaseProvider).raw, changes);
      ref
        ..invalidate(hostsProvider)
        ..invalidate(tunnelsProvider)
        ..invalidate(portableExportStoreProvider);
      if (context.mounted) {
        context.toast(
          l10n.puttyImportDone(changes.hosts.length, changes.tunnels.length),
        );
      }
    } on Object catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'import-putty');
      if (context.mounted) context.toast('$error', isError: true);
    }
    return;
  }
}

/// The account name `ssh` itself would log in as.
String localUsername() =>
    Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? 'root';

/// What the PuTTY preview returned: sessions to import, or a request to
/// choose a `.reg` file instead.
class PuttyChoice {
  const PuttyChoice.sessions(this.sessions) : pickFile = false;
  const PuttyChoice.file() : sessions = const [], pickFile = true;

  final List<PuttySession> sessions;
  final bool pickFile;
}

/// Every session found, SSH ones ticked unless already saved, and plainly
/// what will not come across: `.ppk` keys, proxies, non-SSH sessions.
class PuttyImportDialog extends StatefulWidget {
  const PuttyImportDialog({
    required this.candidates,
    required this.source,
    this.username,
    super.key,
  });

  final List<PuttyCandidate> candidates;
  final String source;

  /// The fallback user name shown for sessions without one. Tests pin it.
  final String? username;

  static const confirmKey = ValueKey('putty-import-confirm');

  @override
  State<PuttyImportDialog> createState() => _PuttyImportDialogState();
}

class _PuttyImportDialogState extends State<PuttyImportDialog> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.candidates.length; i++)
      if (widget.candidates[i].session.importable &&
          !widget.candidates[i].alreadySaved)
        i,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final warn = theme.textTheme.bodySmall?.copyWith(color: scheme.error);
    final username = widget.username ?? localUsername();

    final ppkHosts = [
      for (final i in _selected)
        if (widget.candidates[i].session.keyFile != null)
          widget.candidates[i].session.name,
    ];

    return AlertDialog(
      icon: const Icon(PiconsRegular.terminalWindow),
      title: Text(l10n.puttyImportTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.maxMessageWidth + Spacing.xxxl * 3,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.importJsonFrom(widget.source),
                style: Mono.apply(muted),
              ),
              const SizedBox(height: Spacing.sm),
              for (var i = 0; i < widget.candidates.length; i++)
                _row(context, i, muted, warn, username),
              if (ppkHosts.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                Card.outlined(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PiconsRegular.key,
                              size: 18,
                              color: scheme.tertiary,
                            ),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Text(
                                l10n.puttyPpkTitle,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          l10n.puttyPpkBody(ppkHosts.join(', ')),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const PuttyChoice.file()),
          child: Text(l10n.puttyChooseFile),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: PuttyImportDialog.confirmKey,
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  PuttyChoice.sessions([
                    for (final i in _selected.toList()..sort())
                      widget.candidates[i].session,
                  ]),
                ),
          child: Text(l10n.puttyImportAction(_selected.length)),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    int index,
    TextStyle? muted,
    TextStyle? warn,
    String username,
  ) {
    final l10n = AppLocalizations.of(context);
    final candidate = widget.candidates[index];
    final session = candidate.session;
    final skip = session.skip;

    final notes = <(String, bool)>[
      if (skip == PuttySkip.notSsh)
        (l10n.puttySkippedProtocol(session.protocol), false),
      if (skip == PuttySkip.noHostName) (l10n.puttySkippedNoHost, false),
      if (skip == null) ...[
        if (candidate.alreadySaved) (l10n.puttyAlreadySaved, false),
        if (session.username == null) (l10n.puttyNoUsername(username), false),
        if (session.keyFile case final file?) (l10n.puttyPpk(file), true),
        if (session.proxy case final proxy?)
          (l10n.puttyProxy(proxy.description), true),
        if (session.forwards.isNotEmpty)
          (l10n.puttyForwards(session.forwards.length), false),
        if (session.invalidForwards.isNotEmpty)
          (l10n.puttyInvalidForwards(session.invalidForwards.join(', ')), true),
      ],
    ];

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selected.contains(index),
      onChanged: skip != null
          ? null
          : (checked) => setState(() {
              if (checked ?? false) {
                _selected.add(index);
              } else {
                _selected.remove(index);
              }
            }),
      title: Text(session.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (session.hostname.isNotEmpty)
            Text(session.address, style: Mono.apply(muted)),
          for (final (text, isWarning) in notes)
            Text(text, style: isWarning ? warn : muted),
        ],
      ),
    );
  }
}
