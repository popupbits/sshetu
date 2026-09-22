import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:picons/picons.dart';

import '../../../core/providers.dart';
import '../../../core/ssh/known_hosts_file.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../import/known_hosts_import.dart';

/// No real `known_hosts` is anywhere near this: a few hundred bytes a line,
/// and a machine with ten thousand hosts is still under 5 MB. Anything
/// bigger is the wrong file, and reading it whole would only hurt.
const _maxKnownHostsBytes = 5 * 1024 * 1024;

/// Settings → Trusted host keys → Import from known_hosts: pick a file,
/// preview what it would change, and trust the new keys on confirmation.
///
/// On a desktop the picker opens in `~/.ssh`, where OpenSSH keeps the file.
/// Nothing is read until the user picks one.
Future<void> importKnownHosts(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final file = await openFile(initialDirectory: _sshDirectory());
  if (file == null || !context.mounted) return;

  final String text;
  try {
    if (await file.length() > _maxKnownHostsBytes) {
      if (context.mounted) {
        context.toast(l10n.knownHostsImportTooLarge, isError: true);
      }
      return;
    }
    text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  } on Object {
    if (context.mounted) {
      context.toast(l10n.knownHostsImportReadFailed, isError: true);
    }
    return;
  }

  final store = await ref.read(knownHostsProvider.future);
  final preview = previewKnownHostsImport(
    parseKnownHosts(text),
    store.all(),
    now: DateTime.now().toUtc(),
  );
  if (!context.mounted) return;

  final confirmed = await showKnownHostsImportPreview(
    context,
    preview,
    source: file.path.isEmpty ? file.name : file.path,
  );
  if (!confirmed || !context.mounted) return;

  final written = await applyKnownHostsImport(store, preview);
  ref.invalidate(knownHostsProvider);
  if (context.mounted) context.toast(l10n.knownHostsImported(written));
}

String? _sshDirectory() {
  if (kIsWeb || !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    return null;
  }
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  return home == null ? null : p.join(home, '.ssh');
}

/// The preview: what would be trusted, what already is, what conflicts and
/// is left alone, and what the file held that cannot be imported. Returns
/// true when the user confirms.
Future<bool> showKnownHostsImportPreview(
  BuildContext context,
  KnownHostsImportPreview preview, {
  required String source,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) =>
        KnownHostsImportDialog(preview: preview, source: source),
  );
  return result ?? false;
}

class KnownHostsImportDialog extends StatelessWidget {
  const KnownHostsImportDialog({
    required this.preview,
    required this.source,
    super.key,
  });

  final KnownHostsImportPreview preview;
  final String source;

  static const confirmKey = ValueKey('known-hosts-import-confirm');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parsed = preview.parsed;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final skippedLines = <String>[
      if (parsed.skippedCount(KnownHostsSkip.revoked) > 0)
        l10n.knownHostsImportRevoked(
          parsed.skippedCount(KnownHostsSkip.revoked),
        ),
      if (parsed.skippedCount(KnownHostsSkip.certAuthority) > 0)
        l10n.knownHostsImportCertAuthority(
          parsed.skippedCount(KnownHostsSkip.certAuthority),
        ),
      if (parsed.wildcardNames > 0)
        l10n.knownHostsImportWildcards(parsed.wildcardNames),
      if (parsed.skippedCount(KnownHostsSkip.unsupportedKeyType) > 0)
        l10n.knownHostsImportUnsupported(
          parsed.skippedCount(KnownHostsSkip.unsupportedKeyType),
        ),
      if (parsed.skippedCount(KnownHostsSkip.malformed) > 0)
        l10n.knownHostsImportMalformed(
          parsed.skippedCount(KnownHostsSkip.malformed),
          _lineList(parsed.skipped[KnownHostsSkip.malformed]!),
        ),
      if (preview.alternateKeys > 0)
        l10n.knownHostsImportAlternates(preview.alternateKeys),
    ];

    return AlertDialog(
      icon: const Icon(PiconsRegular.shieldCheck),
      title: Text(l10n.knownHostsImportTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.maxMessageWidth + Spacing.xxxl * 3,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.knownHostsImportFrom(source), style: Mono.apply(muted)),
              const SizedBox(height: Spacing.lg),
              _CountRow(
                icon: PiconsRegular.plusCircle,
                color: scheme.primary,
                text: preview.isEmpty
                    ? l10n.knownHostsImportNothing
                    : l10n.knownHostsImportNew(preview.toTrust.length),
              ),
              if (preview.newHashed > 0)
                Padding(
                  padding: const EdgeInsets.only(
                    left: Spacing.xl,
                    bottom: Spacing.sm,
                  ),
                  child: Text(
                    l10n.knownHostsImportNewHashed(preview.newHashed),
                    style: muted,
                  ),
                ),
              _CountRow(
                icon: PiconsRegular.checkCircle,
                color: scheme.onSurfaceVariant,
                text: l10n.knownHostsImportAlready(preview.alreadyTrusted),
              ),
              if (preview.conflicts.isNotEmpty) ...[
                _CountRow(
                  icon: PiconsRegular.warning,
                  color: scheme.error,
                  text: l10n.knownHostsImportConflicts(
                    preview.conflicts.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: Spacing.xl,
                    bottom: Spacing.sm,
                  ),
                  child: Text(l10n.knownHostsImportConflictsBody, style: muted),
                ),
                for (final conflict in preview.conflicts)
                  _ConflictTile(conflict: conflict),
              ],
              if (skippedLines.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                Text(
                  l10n.knownHostsImportSkipped,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: Spacing.xs),
                for (final line in skippedLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xxs),
                    child: Text('• $line', style: muted),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: preview.isEmpty
              ? null
              : () => Navigator.of(context).pop(true),
          child: Text(l10n.knownHostsImportAction(preview.toTrust.length)),
        ),
      ],
    );
  }

  /// "3, 7, 12" — at most a handful, so a file of garbage does not produce
  /// a dialog of numbers.
  static String _lineList(List<int> lines) {
    const shown = 5;
    final head = lines.take(shown).join(', ');
    return lines.length > shown ? '$head, …' : head;
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Spacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _ConflictTile extends StatelessWidget {
  const _ConflictTile({required this.conflict});

  final KnownHostsConflict conflict;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mono = Mono.apply(theme.textTheme.bodySmall);
    return Padding(
      padding: const EdgeInsets.only(left: Spacing.xl, bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conflict.trusted.isHashed
                ? l10n.knownHostsHashedTitle
                : conflict.address,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SelectableText(
            l10n.knownHostsImportTrusted(
              '${conflict.trusted.keyType} ${conflict.trusted.fingerprint}',
            ),
            style: mono,
          ),
          for (final key in conflict.fileKeys)
            SelectableText(
              l10n.knownHostsImportInFile('${key.keyType} ${key.fingerprint}'),
              style: mono.copyWith(color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }
}
