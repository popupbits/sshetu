import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/ssh/key_generator.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/ssh_identity.dart';
import '../keys_controller.dart';

/// Makes a new key, names it, and shows the public half.
///
/// The step that was missing on a phone. There is no `~/.ssh` on iOS or
/// Android and no way to make one, so before this every key had to be
/// generated on a computer and carried across — which meant the mobile app
/// could not take a user from "installed" to "connected" by itself.
///
/// It ends on the public key rather than a success message, because that is
/// the next thing the user has to do: put this line in the server's
/// `authorized_keys`. Closing without copying is recoverable — the key's own
/// menu offers it again — but making them go looking is not the finish this
/// deserves.
Future<void> showGenerateKeySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _GenerateKeySheet(),
  );
}

class _GenerateKeySheet extends ConsumerStatefulWidget {
  const _GenerateKeySheet();

  @override
  ConsumerState<_GenerateKeySheet> createState() => _GenerateKeySheetState();
}

class _GenerateKeySheetState extends ConsumerState<_GenerateKeySheet> {
  final _label = TextEditingController();
  GeneratedKey? _generated;
  var _saving = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final label = _label.text.trim();
    if (label.isEmpty || _saving) return;
    setState(() => _saving = true);

    // The comment is what shows beside the key in a server's
    // `authorized_keys` months from now, when someone is deciding whether it
    // is still needed. A label the user chose beats `user@device`.
    final key = SshKeyGenerator.ed25519(comment: label);
    final now = DateTime.now().toUtc();

    await ref
        .read(identitiesControllerProvider)
        .save(
          SshIdentity(
            id: '${now.microsecondsSinceEpoch}',
            label: label,
            keyType: key.keyType,
            publicKey: key.publicKey,
            fingerprint: key.fingerprint,
            origin: IdentityOrigin.generated,
            createdAt: now,
            updatedAt: now,
          ),
          privateKey: key.privateKey,
        );

    if (mounted) setState(() => _generated = key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final generated = _generated;

    return Padding(
      // Above the keyboard, which is up the moment this opens.
      padding: EdgeInsets.only(
        left: Spacing.xl,
        right: Spacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.keysGenerateTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.keysGenerateBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          if (generated == null)
            ..._form(l10n)
          else
            ..._result(l10n, theme, generated),
        ],
      ),
    );
  }

  List<Widget> _form(AppLocalizations l10n) => [
    TextField(
      controller: _label,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(labelText: l10n.keysGenerateLabel),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _generate(),
    ),
    const SizedBox(height: Spacing.lg),
    Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: _label.text.trim().isEmpty || _saving ? null : _generate,
        icon: const Icon(PiconsRegular.key),
        label: Text(l10n.keysGenerate),
      ),
    ),
  ];

  List<Widget> _result(
    AppLocalizations l10n,
    ThemeData theme,
    GeneratedKey generated,
  ) => [
    Text(l10n.keysGenerateDone, style: theme.textTheme.bodyMedium),
    const SizedBox(height: Spacing.md),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      // Selectable as well as copyable: on a desktop, selecting part of it
      // is how someone checks it against what is already on the server.
      child: SelectableText(
        generated.publicKey,
        style: Mono.apply(theme.textTheme.bodySmall),
      ),
    ),
    const SizedBox(height: Spacing.lg),
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
        const SizedBox(width: Spacing.sm),
        FilledButton.icon(
          onPressed: () async {
            // Captured before the await: `context` here is the State's, and
            // the analyzer is right that reading it after a gap is a
            // different question from whether this State is still mounted.
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            final copied = l10n.keysCopied;

            await Clipboard.setData(ClipboardData(text: generated.publicKey));
            if (!mounted) return;
            messenger.showSnackBar(SnackBar(content: Text(copied)));
            navigator.pop();
          },
          icon: const Icon(PiconsRegular.copy),
          label: Text(l10n.keysCopyPublic),
        ),
      ],
    ),
  ];
}
