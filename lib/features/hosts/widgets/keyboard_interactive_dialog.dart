import 'package:material_ui/material_ui.dart';

import '../../../core/ssh/keyboard_interactive.dart';
import '../../../core/ssh/vault_credential_source.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';

/// Asks the user one round of keyboard-interactive questions from a server.
///
/// Returns null when they cancel, which fails the sign-in with a message
/// saying so. A server that asks a password round and then a code round
/// raises this twice, one dialog per round.
Future<KeyboardInteractiveReply?> showKeyboardInteractiveDialog(
  BuildContext context,
  KeyboardInteractiveRequest request,
) => showDialog<KeyboardInteractiveReply>(
  context: context,
  builder: (context) => KeyboardInteractiveDialog(request: request),
);

/// The questions of one keyboard-interactive round, as a form.
///
/// Everything the server said is shown verbatim — its name, its instruction,
/// each prompt — because the server is the only one who knows what it is
/// asking for, and a PAM stack can ask for anything. The address is shown too:
/// in a jump chain the bastion and the host behind it each ask, and a code for
/// one is not a code for the other.
class KeyboardInteractiveDialog extends StatefulWidget {
  const KeyboardInteractiveDialog({super.key, required this.request});

  final KeyboardInteractiveRequest request;

  @override
  State<KeyboardInteractiveDialog> createState() =>
      _KeyboardInteractiveDialogState();
}

class _KeyboardInteractiveDialogState extends State<KeyboardInteractiveDialog> {
  late final List<TextEditingController> _controllers;
  late final List<bool> _obscured;
  var _remember = false;

  List<KeyboardInteractivePrompt> get _prompts =>
      widget.request.challenge.prompts;

  @override
  void initState() {
    super.initState();
    _controllers = [for (final _ in _prompts) TextEditingController()];
    _obscured = [for (final prompt in _prompts) !prompt.echo];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(
    KeyboardInteractiveReply([
      for (final controller in _controllers) controller.text,
    ], remember: widget.request.canRemember && _remember),
  );

  /// A hint for the platform's autofill and keyboard: a one-time code gets
  /// the code suggestion (iOS offers the one it just received by SMS), a
  /// password gets the password manager. Nothing is assumed numeric — plenty
  /// of codes are not.
  static Iterable<String>? _autofillHints(KeyboardInteractivePrompt prompt) {
    if (looksLikeOneTimeCode(prompt.text)) {
      return const [AutofillHints.oneTimeCode];
    }
    if (!prompt.echo && prompt.text.toLowerCase().contains('password')) {
      return const [AutofillHints.password];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final challenge = widget.request.challenge;
    final name = challenge.name.trim();
    final instruction = challenge.instruction.trim();

    return AlertDialog(
      title: Text(name.isEmpty ? l10n.interactiveAuthTitle : name),
      // Scrollable so a multi-prompt round still fits above a phone's
      // software keyboard instead of overflowing behind it.
      scrollable: true,
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
          if (instruction.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            Text(instruction, style: theme.textTheme.bodyMedium),
          ],
          for (var i = 0; i < _prompts.length; i++) ...[
            const SizedBox(height: Spacing.lg),
            _field(i, l10n),
          ],
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
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.interactiveAuthSubmit),
        ),
      ],
    );
  }

  Widget _field(int index, AppLocalizations l10n) {
    final prompt = _prompts[index];
    final isLast = index == _prompts.length - 1;
    final label = prompt.text.trim();

    return TextField(
      controller: _controllers[index],
      // The first field, so the software keyboard comes up with the dialog.
      autofocus: index == 0,
      obscureText: _obscured[index],
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: _autofillHints(prompt),
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      // Enter submits from the last field and moves on from the others: this
      // dialog interrupts a connection the user already asked for.
      onSubmitted: (_) =>
          isLast ? _submit() : FocusScope.of(context).nextFocus(),
      decoration: InputDecoration(
        labelText: label.isEmpty ? l10n.interactiveAuthAnswerLabel : label,
        border: const OutlineInputBorder(),
        suffixIcon: prompt.echo
            ? null
            : IconButton(
                icon: Icon(
                  _obscured[index] ? Icons.visibility : Icons.visibility_off,
                ),
                tooltip: _obscured[index] ? l10n.actionShow : l10n.actionHide,
                onPressed: () =>
                    setState(() => _obscured[index] = !_obscured[index]),
              ),
      ),
    );
  }
}
