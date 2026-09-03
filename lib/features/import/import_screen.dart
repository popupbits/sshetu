import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/error/error_logger.dart';
import '../../core/ssh/openssh_import.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/feedback.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'import_controller.dart';

/// What an import screen was opened to bring in.
enum ImportFocus {
  /// Both, from the Hosts tab or Settings.
  all,

  /// Keys only, from the Keys tab.
  keys;

  static ImportFocus parse(String? value) =>
      value == 'keys' ? ImportFocus.keys : ImportFocus.all;

  bool get showsHosts => this == ImportFocus.all;
}

/// Finds an existing OpenSSH setup and offers to bring it in.
///
/// Everything is shown before anything is written, and every row starts
/// selected: the common case is "yes, all of it", and the review exists so the
/// user can *deselect* the two hosts they no longer use — not so they have to
/// tick forty boxes to get what they asked for.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({this.focus = ImportFocus.all, super.key});

  /// What this screen was opened to import.
  final ImportFocus focus;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _hosts = <String>{};
  final _keys = <String>{};
  var _seeded = false;
  var _busy = false;

  void _seed(OpenSshScanResult scan) {
    if (_seeded) return;
    _seeded = true;
    // Only what this screen is for. Pre-ticking things the user did not come
    // here to import turns a stray tap into an import they have to undo.
    if (widget.focus.showsHosts) {
      _hosts.addAll(scan.hosts.map((h) => h.alias));
    }
    _keys.addAll(scan.keys.map((k) => k.path));
  }

  /// Asks the user to point at their `.ssh` folder.
  ///
  /// On macOS this is not a fallback but the primary route: the sandbox denies
  /// `~/.ssh` outright, and picking the folder is precisely what grants
  /// permission to read it. Opening a panel is also the honest interaction —
  /// the app is about to read every private key the user owns, and that should
  /// take a deliberate act, not a silent scan.
  Future<void> _pickDirectory() async {
    final path = await getDirectoryPath(
      confirmButtonText: AppLocalizations.of(context).importChooseFolderConfirm,
      initialDirectory: OpenSshScanner().defaultSshPath,
    );
    if (path == null || !mounted) return;
    setState(() {
      _seeded = false;
      _hosts.clear();
      _keys.clear();
    });
    ref.read(pickedSshDirectoryProvider.notifier).set(path);
  }

  Future<void> _import(OpenSshScanResult scan) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      final outcome = await ref
          .read(importControllerProvider)
          .import(scan: scan, hostAliases: _hosts, keyPaths: _keys);
      if (!mounted) return;
      context.toast(l10n.importDone(outcome.hosts, outcome.keys));
      Navigator.of(context).maybePop();
    } on Object catch (e, stackTrace) {
      // Into the on-device log as well as the toast. A toast is gone in three
      // seconds, and this is exactly the failure someone will report later as
      // "importing my keys didn't work" — Settings > Diagnostics is where they
      // can then find what actually happened, with the platform's error code.
      ErrorLogger.instance.record(e, stackTrace, source: 'import');
      if (!mounted) return;
      setState(() => _busy = false);
      context.toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scan = ref.watch(openSshScanProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.focus == ImportFocus.keys ? l10n.keysImport : l10n.importTitle,
        ),
        actions: [
          IconButton(
            tooltip: l10n.importChooseFolder,
            icon: const Icon(PiconsRegular.folderOpen),
            onPressed: _pickDirectory,
          ),
          IconButton(
            tooltip: l10n.importRescan,
            icon: const Icon(PiconsRegular.arrowClockwise),
            onPressed: () {
              _seeded = false;
              _hosts.clear();
              _keys.clear();
              ref.invalidate(openSshScanProvider);
            },
          ),
        ],
      ),
      body: scan.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(openSshScanProvider),
          retryLabel: l10n.actionRetry,
        ),
        data: (result) {
          if (!OpenSshScanner.canAutoDetect) {
            return EmptyView(
              icon: PiconsRegular.deviceMobile,
              title: l10n.importUnavailableTitle,
              message: l10n.importUnavailableBody,
            );
          }
          final nothingToShow = widget.focus.showsHosts
              ? result.isEmpty
              : result.keys.isEmpty;
          if (nothingToShow) {
            return EmptyView(
              icon: PiconsRegular.folderOpen,
              title: l10n.importNothingTitle,
              message: OpenSshScanner.canScanHomeDirectly
                  ? l10n.importNothingBody
                  : l10n.importChooseFolderBody,
              action: FilledButton.icon(
                onPressed: _pickDirectory,
                icon: const Icon(PiconsRegular.folderOpen),
                label: Text(l10n.importChooseFolder),
              ),
            );
          }
          _seed(result);
          return _Review(
            result: result,
            focus: widget.focus,
            hosts: _hosts,
            keys: _keys,
            onChanged: () => setState(() {}),
          );
        },
      ),
      bottomNavigationBar: scan.maybeWhen(
        data: (result) =>
            (widget.focus.showsHosts ? result.isEmpty : result.keys.isEmpty) ||
                !OpenSshScanner.canAutoDetect
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: FilledButton.icon(
                    onPressed: _busy || (_hosts.isEmpty && _keys.isEmpty)
                        ? null
                        : () => _import(result),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(PiconsRegular.downloadSimple),
                    label: Text(
                      l10n.importAction(_hosts.length + _keys.length),
                    ),
                  ),
                ),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({
    required this.result,
    required this.focus,
    required this.hosts,
    required this.keys,
    required this.onChanged,
  });

  final OpenSshScanResult result;
  final ImportFocus focus;
  final Set<String> hosts;
  final Set<String> keys;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        children: [
          if (result.sshDirectory != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.lg,
                0,
              ),
              child: Card.filled(
                child: ListTile(
                  leading: const Icon(PiconsRegular.info),
                  title: Text(l10n.importFoundIn(result.sshDirectory!)),
                  // Said plainly, because the user is about to let an app read
                  // the directory holding every key they own.
                  subtitle: Text(l10n.importNoteBody),
                ),
              ),
            ),

          if (result.keys.isNotEmpty) ...[
            SectionLabel(l10n.importKeysSection),
            for (final key in result.keys)
              CheckboxListTile(
                value: keys.contains(key.path),
                onChanged: (checked) {
                  if (checked ?? false) {
                    keys.add(key.path);
                  } else {
                    keys.remove(key.path);
                  }
                  onChanged();
                },
                title: Text(key.label),
                subtitle: Text(
                  [
                    key.keyType,
                    if (key.isEncrypted) l10n.keysEncrypted,
                    if (key.fingerprint != null) key.fingerprint!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: const Icon(PiconsRegular.key),
              ),
          ],

          if (focus.showsHosts && result.hosts.isNotEmpty) ...[
            SectionLabel(l10n.importHostsSection),
            for (final host in result.hosts)
              CheckboxListTile(
                value: hosts.contains(host.alias),
                onChanged: (checked) {
                  if (checked ?? false) {
                    hosts.add(host.alias);
                  } else {
                    hosts.remove(host.alias);
                  }
                  onChanged();
                },
                title: Text(host.alias),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(host.description),
                    // Surfaced, not swallowed: a user whose ProxyCommand did
                    // not come across should learn it here rather than when a
                    // connection behaves differently than it does in their
                    // terminal.
                    if (host.unsupported.isNotEmpty)
                      Text(
                        l10n.importUnsupported(host.unsupported.join(', ')),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
                isThreeLine: host.unsupported.isNotEmpty,
                secondary: const Icon(PiconsRegular.hardDrive),
              ),
          ],
        ],
      ),
    );
  }
}
