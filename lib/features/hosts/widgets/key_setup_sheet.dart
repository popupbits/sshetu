import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/providers.dart';
import '../../../core/ssh/ssh_connection.dart';
import '../../../core/ssh/ssh_credentials.dart';
import '../../../core/ssh/ssh_target.dart';
import '../../../core/secrets/secret_ref.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../keys/domain/ssh_identity.dart';
import '../../keys/keys_controller.dart';
import '../hosts_controller.dart';
import '../data/key_setup_service.dart';
import '../domain/key_setup.dart';
import '../domain/ssh_host.dart';

/// Offers to swap a password login for a key, over the session already open.
///
/// Only from a live connection, and that is the point rather than a
/// limitation: installing a key needs a way in, and the way in someone
/// already has is the password we are trying to stop needing.
Future<void> showKeySetupSheet(
  BuildContext context, {
  required SshHost host,
  required SshConnection connection,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _KeySetupSheet(host: host, connection: connection),
);

class _KeySetupSheet extends ConsumerStatefulWidget {
  const _KeySetupSheet({required this.host, required this.connection});

  final SshHost host;
  final SshConnection connection;

  @override
  ConsumerState<_KeySetupSheet> createState() => _KeySetupSheetState();
}

class _KeySetupSheetState extends ConsumerState<_KeySetupSheet> {
  String? _identityId;
  KeySetupStep? _step;
  String? _error;
  String? _detail;
  String? _done;

  bool get _busy => _step != null;

  Future<void> _start(List<SshIdentity> identities) async {
    final identity = identities.firstWhere((i) => i.id == _identityId);
    final l10n = AppLocalizations.of(context);
    final vault = ref.read(secretVaultProvider);

    setState(() {
      _error = null;
      _detail = null;
      _step = KeySetupStep.installing;
    });

    try {
      final publicKey = identity.publicKey;
      if (publicKey == null || publicKey.trim().isEmpty) {
        throw const KeySetupException(
          'That key has no public half stored, so there is nothing to install.',
        );
      }

      final pem = await vault.read(SecretRef.identityPrivateKey(identity.id));
      if (pem == null) {
        throw const KeySetupException(
          'That key is missing its private half on this device.',
        );
      }

      final client = await widget.connection.client();
      final target = await ref
          .read(hostRepositoryProvider)
          .targetFor(widget.host);

      final service = KeySetupService(
        vault: vault,
        run: (script, stdin) => runScript(client, script, stdin),
        verify: (verifyTarget, credentials) async {
          // A *new* connection, not this one. Reusing the open session would
          // prove only that the session already open still works.
          final probe = SshConnection(
            target: verifyTarget,
            verifierFactory: widget.connection.verifierFactory,
            credentials: credentials,
            maxAttempts: 1,
          );
          try {
            await probe.client();
          } finally {
            await probe.close();
          }
        },
      );

      final result = await service.run_(
        target: target,
        publicKey: publicKey,
        privateKey: SshPrivateKey(
          identityId: identity.id,
          label: identity.label,
          pem: pem,
          passphrase: await vault.read(
            SecretRef.identityPassphrase(identity.id),
          ),
        ),
        hostId: widget.host.id,
        onStep: (step) {
          if (mounted) setState(() => _step = step);
        },
      );

      // The row changes only once the key has actually logged in.
      await ref.read(hostRepositoryProvider).save(
        widget.host.copyWith(
          authMethod: SshAuthMethod.publicKey,
          identityId: identity.id,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      ref.invalidate(hostsProvider);

      if (!mounted) return;
      setState(() {
        _step = null;
        _done = result.installed == KeyInstallOutcome.alreadyPresent
            ? '${l10n.keySetupAlreadyPresent} '
                  '${l10n.keySetupDone(widget.host.label, identity.label)}'
            : l10n.keySetupDone(widget.host.label, identity.label);
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _step = null;
        _error = error is KeySetupException
            ? error.message
            : '$error';
        _detail = error is KeySetupException ? error.detail : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final identities = ref.watch(identitiesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          0,
          Spacing.xl,
          Spacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.keySetupTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.keySetupBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),

            if (_done case final message?) ...[
              _Outcome(
                icon: PiconsRegular.checkCircle,
                color: theme.colorScheme.primary,
                message: message,
              ),
              const SizedBox(height: Spacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.actionClose),
              ),
            ] else ...[
              switch (identities) {
                AsyncData(:final value) when value.isEmpty => Text(
                  l10n.keySetupNoKeys,
                  style: theme.textTheme.bodyMedium,
                ),
                AsyncData(:final value) => _KeyChoice(
                  identities: value,
                  selected: _identityId,
                  enabled: !_busy,
                  onChanged: (id) => setState(() => _identityId = id),
                ),
                AsyncError(:final error) => Text('$error'),
                _ => const Padding(
                  padding: EdgeInsets.all(Spacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
              const SizedBox(height: Spacing.lg),

              // Said before the button, not after: the sentence people need
              // is "this does not touch the server's configuration", and it
              // is worth reading before rather than regretting after.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PiconsRegular.info,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      l10n.keySetupServerNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),

              if (_error case final message?) ...[
                const SizedBox(height: Spacing.lg),
                _Outcome(
                  icon: PiconsRegular.warning,
                  color: theme.colorScheme.error,
                  message: message,
                  detail: _detail,
                ),
              ],

              const SizedBox(height: Spacing.lg),
              Row(
                children: [
                  if (_step case final step?) ...[
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        switch (step) {
                          KeySetupStep.installing => l10n.keySetupInstalling,
                          KeySetupStep.verifying => l10n.keySetupVerifying,
                          KeySetupStep.finishing => l10n.keySetupFinishing,
                          KeySetupStep.rollingBack => l10n.keySetupRollingBack,
                        },
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  FilledButton.icon(
                    onPressed: _busy || _identityId == null
                        ? null
                        : () => unawaited(
                            _start(identities.value ?? const []),
                          ),
                    icon: const Icon(PiconsRegular.key, size: 18),
                    label: Text(l10n.keySetupStart),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The keys, one tap each.
class _KeyChoice extends StatelessWidget {
  const _KeyChoice({
    required this.identities,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<SshIdentity> identities;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.keySetupChooseKey, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Spacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: RadioGroup<String>(
            groupValue: selected,
            // RadioGroup wants a non-null callback; disabling is done by the
            // callback declining rather than by removing it.
            onChanged: (id) {
              if (enabled && id != null) onChanged(id);
            },
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final identity in identities)
                  RadioListTile<String>(
                    value: identity.id,
                    title: Text(identity.label),
                    subtitle: Text(identity.keyType),
                    secondary: const Icon(PiconsRegular.key),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.icon,
    required this.color,
    required this.message,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: theme.textTheme.bodyMedium),
              // What the server itself said. Almost always more useful than
              // anything written here in advance.
              if (detail case final text? when text.isNotEmpty) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
