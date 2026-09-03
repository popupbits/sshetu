import 'package:material_ui/material_ui.dart';

import '../../../core/ssh/vault_credential_source.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Asks for a password or a key passphrase.
///
/// The address is in the title on purpose. With three sessions open, a dialog
/// that says only "Password:" is a dialog people type the wrong password into
/// — and a password typed at the wrong host is a password disclosed to it.
Future<SecretResponse?> showSecretDialog(
  BuildContext context,
  SecretRequest request,
) => showDialog<SecretResponse>(
  context: context,
  builder: (context) => _SecretDialog(request: request),
);

class _SecretDialog extends StatefulWidget {
  const _SecretDialog({required this.request});

  final SecretRequest request;

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  final _controller = TextEditingController();
  var _remember = false;
  var _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() =>
      Navigator.of(context)
          .pop(SecretResponse(_controller.text, remember: _remember));

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
            widget.request.address,
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.secretUnlock)),
      ],
    );
  }
}
