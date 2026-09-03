import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/router/navigation.dart';
import '../../../core/router/routes.dart';
import '../../../core/ssh/vault_credential_source.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../keys/domain/ssh_identity.dart';
import '../../keys/keys_controller.dart';

/// What the user did with a secret prompt.
sealed class SecretDialogOutcome {
  const SecretDialogOutcome();
}

/// They typed the secret.
class SecretSupplied extends SecretDialogOutcome {
  const SecretSupplied(this.response);

  final SecretResponse response;
}

/// They would rather authenticate with a key.
///
/// Being asked for a password when you have a perfectly good key, and having
/// no way to say so without cancelling and hunting for the host editor, is a
/// dead end — and the moment the app asks is exactly the moment the user knows
/// which key it should have used.
class SecretUseIdentity extends SecretDialogOutcome {
  const SecretUseIdentity(this.identityId, {required this.remember});

  final String identityId;

  /// Whether to save the choice on the host, so it is used from now on rather
  /// than only for this attempt.
  final bool remember;
}

/// Asks for a password or a key passphrase.
///
/// The address is in the title on purpose. With three sessions open, a dialog
/// that says only "Password:" is a dialog people type the wrong password into
/// — and a password typed at the wrong host is a password disclosed to it.
Future<SecretDialogOutcome?> showSecretDialog(
  BuildContext context,
  SecretRequest request,
) => showDialog<SecretDialogOutcome>(
  context: context,
  builder: (context) => _SecretDialog(request: request),
);

class _SecretDialog extends ConsumerStatefulWidget {
  const _SecretDialog({required this.request});

  final SecretRequest request;

  @override
  ConsumerState<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends ConsumerState<_SecretDialog> {
  final _controller = TextEditingController();
  var _remember = false;
  var _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(
    context,
  ).pop(SecretSupplied(SecretResponse(_controller.text, remember: _remember)));

  Future<void> _pickKey() async {
    // `.future`, not `.value`. Nothing on this screen watches identities, so
    // the provider has never been resolved and `.value` is null — which the
    // picker faithfully rendered as "you have no keys" to a user who has two.
    final identities = await ref.read(identitiesProvider.future);
    if (!mounted) return;
    final choice = await showDialog<SecretUseIdentity>(
      context: context,
      builder: (context) => _KeyPicker(identities: identities),
    );
    if (choice != null && mounted) Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isPassword = widget.request.kind == SecretRequestKind.password;

    return AlertDialog(
      title: Text(
        isPassword ? l10n.secretPasswordTitle : l10n.secretPassphraseTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.request.subject ?? widget.request.address,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscured,
            // Enter submits: this dialog interrupts a connection the user
            // already asked for, so reaching for the mouse is friction.
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
          if (widget.request.canRemember) ...[
            const SizedBox(height: Spacing.sm),
            CheckboxListTile(
              value: _remember,
              onChanged: (value) => setState(() => _remember = value ?? false),
              title: Text(l10n.secretRemember),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
        ],
      ),
      actions: [
        // Only for a password. A passphrase prompt is already about a specific
        // key, so "use a key instead" would be asking which key to use to
        // unlock the key.
        if (isPassword)
          TextButton.icon(
            onPressed: _pickKey,
            icon: const Icon(PiconsRegular.key, size: 16),
            label: Text(l10n.secretUseKeyInstead),
          ),
        // No Spacer here, however much this row wants one: AlertDialog lays
        // its actions out in an OverflowBar, which has no concept of flex and
        // throws on an Expanded child. It threw on every password prompt.
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.secretUnlock)),
      ],
    );
  }
}

/// Picks which key to authenticate with, and whether to keep the choice.
class _KeyPicker extends StatefulWidget {
  const _KeyPicker({required this.identities});

  final List<SshIdentity> identities;

  @override
  State<_KeyPicker> createState() => _KeyPickerState();
}

class _KeyPickerState extends State<_KeyPicker> {
  /// Saving is the default, because it is the point. Someone reaching for a
  /// key while being asked for a password is telling you the host is
  /// configured wrong; fixing it only for this attempt would mean the same
  /// dialog again next time.
  var _remember = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (widget.identities.isEmpty) {
      return AlertDialog(
        title: Text(l10n.secretPickKey),
        content: Text(l10n.secretNoKeys),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.pushTo(Routes.importFocused('keys'));
            },
            icon: const Icon(PiconsRegular.downloadSimple, size: 16),
            label: Text(l10n.keysImport),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.secretPickKey),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.identities.length,
                itemBuilder: (context, index) {
                  final identity = widget.identities[index];
                  return ListTile(
                    leading: const Icon(PiconsRegular.key),
                    title: Text(identity.label),
                    subtitle: Text(
                      [
                        identity.keyType,
                        if (identity.hasPassphrase) l10n.keysEncrypted,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(SecretUseIdentity(identity.id, remember: _remember)),
                  );
                },
              ),
            ),
            const Divider(),
            CheckboxListTile(
              value: _remember,
              onChanged: (value) => setState(() => _remember = value ?? false),
              title: Text(l10n.secretPickKeyBody),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              subtitle: Text(
                l10n.hostEditorAuthKeyHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
      ],
    );
  }
}
