import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../transfer/domain/transfer_payload.dart';
import '../backup_service.dart';
import '../domain/backup_file.dart';

/// Restoring from a backup file.
///
/// Three deliberate steps: pick a file, prove you can open it, then look at
/// what came out and say yes. Restoring writes over rows that share an id, so
/// the confirmation is not a formality — the same reason the receive screen
/// shows an offer before it takes one.
class BackupImportScreen extends ConsumerStatefulWidget {
  const BackupImportScreen({this.embedded = false, this.service, super.key});

  final bool embedded;

  /// Injected by tests, which have no file picker.
  final BackupService? service;

  @override
  ConsumerState<BackupImportScreen> createState() => _BackupImportScreenState();
}

class _BackupImportScreenState extends ConsumerState<BackupImportScreen> {
  final _passphrase = TextEditingController();

  Uint8List? _bytes;
  String? _fileName;
  BackupContents? _contents;
  TransferPayload? _payload;

  var _working = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    setState(() => _error = null);
    try {
      final picked = await (widget.service ?? const BackupService()).pick();
      if (picked == null || !mounted) return;
      setState(() {
        _bytes = picked.bytes;
        _fileName = picked.name;
        // A different file is a different everything: keeping the old
        // decryption on screen beside a new name is how someone restores
        // something they did not mean to.
        _contents = null;
        _payload = null;
        _passphrase.clear();
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _open() async {
    final bytes = _bytes;
    if (bytes == null) return;

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final opened = await (widget.service ?? const BackupService()).decode(
        bytes: bytes,
        passphrase: _passphrase.text,
      );
      if (!mounted) return;
      setState(() {
        _working = false;
        _contents = opened.contents;
        _payload = opened.payload;
        // It has done its job. Nothing is gained by keeping it typed out.
        _passphrase.clear();
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = error is BackupException ? error.message : '$error';
      });
    }
  }

  Future<void> _restore() async {
    final payload = _payload;
    if (payload == null) return;

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      await payload.apply(
        ref.read(databaseProvider).raw,
        vault: ref.read(secretVaultProvider),
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _working = false;
        _bytes = null;
        _fileName = null;
        _contents = null;
        _payload = null;
      });
      context.toast(l10n.backupRestored);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = error is TransferPayloadException
            ? error.message
            : error is BackupException
            ? error.message
            : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final contents = _contents;

    final body = ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(Spacing.xl),
        children: [
          Text(l10n.backupRestoreTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.backupRestoreBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xl),
          OutlinedButton.icon(
            onPressed: _working ? null : () => unawaited(_choose()),
            icon: const Icon(PiconsRegular.folderOpen, size: 18),
            label: Text(_fileName ?? l10n.backupChooseFile),
          ),
          if (_bytes != null && contents == null) ...[
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _passphrase,
              obscureText: _obscure,
              enabled: !_working,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => unawaited(_open()),
              decoration: InputDecoration(
                labelText: l10n.backupPassphrase,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(PiconsRegular.lock),
                suffixIcon: IconButton(
                  tooltip: _obscure ? l10n.actionShow : l10n.actionHide,
                  icon: Icon(
                    _obscure ? PiconsRegular.eye : PiconsRegular.eyeSlash,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: _working ? null : () => unawaited(_open()),
              child: Text(_working ? l10n.backupOpening : l10n.backupOpen),
            ),
          ],
          if (contents != null) ...[
            const SizedBox(height: Spacing.xl),
            // What is actually in the file, from inside the file — not from
            // its name, and not from anything an attacker could have edited.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.backupContents(
                        contents.hosts,
                        contents.identities,
                        contents.tunnels,
                        contents.knownHosts,
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      contents.includesSecrets
                          ? l10n.backupWithSecrets
                          : l10n.backupWithoutSecrets,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: contents.includesSecrets
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      l10n.backupWrittenOn(
                        _formatDate(contents.created),
                        contents.appVersion,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PiconsRegular.warning,
                  size: 14,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    l10n.backupRestoreWarning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton.icon(
              onPressed: _working ? null : () => unawaited(_restore()),
              icon: const Icon(PiconsRegular.checkCircle, size: 18),
              label: Text(l10n.backupRestore),
            ),
          ],
          if (_error case final message?) ...[
            const SizedBox(height: Spacing.lg),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupRestoreTitle)),
      body: body,
    );
  }

  static String _formatDate(DateTime when) =>
      '${when.year}-${when.month.toString().padLeft(2, '0')}-'
      '${when.day.toString().padLeft(2, '0')}';
}
