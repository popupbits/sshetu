import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../backup_service.dart';
import '../domain/backup_file.dart';
import 'passphrase_strength.dart';

/// Saving an encrypted copy of everything on this device.
///
/// This exists because the app deliberately has no cloud account. That is the
/// right call for an SSH client — a server that never holds your keys cannot
/// leak them — but it removes the accidental backup an account gives you for
/// free, and "my laptop died" is a far more common disaster than "my provider
/// was breached". So the backup is explicit, encrypted here, and yours to
/// keep.
class BackupExportScreen extends ConsumerStatefulWidget {
  const BackupExportScreen({this.embedded = false, this.service, super.key});

  final bool embedded;

  /// Injected by tests, which have no file picker.
  final BackupService? service;

  @override
  ConsumerState<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends ConsumerState<BackupExportScreen> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();

  /// On by default, and the opposite of the transfer screen's default.
  ///
  /// A transfer is a convenience — the keys are still on the first device
  /// afterwards. A backup is the copy you reach for when the first device is
  /// gone, and one without keys cannot get you back into anything. The file
  /// is encrypted under a passphrase precisely so this can be the default.
  var _includeSecrets = true;

  var _obscure = true;
  var _working = false;
  String? _error;
  String? _saved;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations l10n) {
    if (_passphrase.text.length < kMinimumPassphrase) {
      return l10n.backupPassphraseTooShort(kMinimumPassphrase);
    }
    if (_passphrase.text != _confirm.text) {
      return l10n.backupPassphraseMismatch;
    }
    return null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final problem = _validate(l10n);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _working = true;
      _error = null;
      _saved = null;
    });

    try {
      final service = widget.service ?? const BackupService();
      final bytes = await service.encode(
        database: ref.read(databaseProvider).raw,
        vault: ref.read(secretVaultProvider),
        passphrase: _passphrase.text,
        includeSecrets: _includeSecrets,
      );
      final result = await service.save(bytes);
      if (!mounted) return;

      setState(() {
        _working = false;
        _saved = switch (result.destination) {
          BackupDestination.saved => l10n.backupSaved(result.path ?? ''),
          BackupDestination.shared => l10n.backupShared,
          BackupDestination.cancelled => null,
        };
        // Written and gone: leaving it in the field would put the one secret
        // that matters on screen for as long as the tab stays open.
        if (_saved != null) {
          _passphrase.clear();
          _confirm.clear();
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = error is BackupException ? error.message : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final body = ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(Spacing.xl),
        children: [
          Text(l10n.backupTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.backupBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xl),
          TextField(
            controller: _passphrase,
            obscureText: _obscure,
            enabled: !_working,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: l10n.backupPassphrase,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(PiconsRegular.lock),
              suffixIcon: IconButton(
                tooltip: _obscure ? l10n.actionShow : l10n.actionHide,
                icon: Icon(_obscure ? PiconsRegular.eye : PiconsRegular.eyeSlash),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _Strength(passphrase: _passphrase.text),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            enabled: !_working,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => unawaited(_save()),
            decoration: InputDecoration(
              labelText: l10n.backupPassphraseConfirm,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(PiconsRegular.lock),
            ),
          ),
          const SizedBox(height: Spacing.md),
          // Said plainly and near the field, not buried in a help page. There
          // is genuinely no recovery: no account, no reset link, nobody to
          // ask. Someone deserves to know that before they choose.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                PiconsRegular.warning,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  l10n.backupPassphraseHelp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          SwitchListTile(
            value: _includeSecrets,
            onChanged: _working
                ? null
                : (value) => setState(() => _includeSecrets = value),
            title: Text(l10n.backupIncludeSecrets),
            subtitle: Text(l10n.backupIncludeSecretsBody),
            secondary: Icon(
              _includeSecrets ? PiconsRegular.key : PiconsRegular.keyhole,
              color: _includeSecrets ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          if (_error case final message?) ...[
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
          if (_saved case final message?) ...[
            Row(
              children: [
                Icon(
                  PiconsRegular.checkCircle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(child: Text(message)),
              ],
            ),
            const SizedBox(height: Spacing.md),
          ],
          FilledButton.icon(
            onPressed: _working ? null : () => unawaited(_save()),
            icon: _working
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PiconsRegular.downloadSimple, size: 18),
            label: Text(
              _working
                  ? l10n.backupWorking
                  : _saved != null
                  ? l10n.backupSaveAnother
                  : l10n.backupExport,
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: body,
    );
  }
}

/// How good the passphrase is, said while there is still time to change it.
class _Strength extends StatelessWidget {
  const _Strength({required this.passphrase});

  final String passphrase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (passphrase.isEmpty) return const SizedBox.shrink();

    final strength = strengthOf(passphrase);
    final (label, color) = switch (strength) {
      PassphraseStrength.weak => (
        l10n.backupStrengthWeak,
        theme.colorScheme.error,
      ),
      PassphraseStrength.fair => (
        l10n.backupStrengthFair,
        theme.colorScheme.tertiary,
      ),
      PassphraseStrength.strong => (
        l10n.backupStrengthStrong,
        theme.colorScheme.primary,
      ),
    };

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: switch (strength) {
              PassphraseStrength.weak => 0.33,
              PassphraseStrength.fair => 0.66,
              PassphraseStrength.strong => 1,
            },
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
