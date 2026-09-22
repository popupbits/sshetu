import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/error/error_logger.dart';
import '../../../core/ssh/key_generator.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
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
/// Ed25519 is preselected and labelled as the recommendation; the other types
/// are there for servers and policies that insist. RSA is generated on a
/// background isolate with a progress line, because finding its primes takes
/// long enough to freeze a frame many times over.
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
    builder: (context) => const GenerateKeySheet(),
  );
}

/// The sheet's body. Public for widget tests; open it with
/// [showGenerateKeySheet].
class GenerateKeySheet extends ConsumerStatefulWidget {
  const GenerateKeySheet({super.key});

  @override
  ConsumerState<GenerateKeySheet> createState() => _GenerateKeySheetState();
}

class _GenerateKeySheetState extends ConsumerState<GenerateKeySheet> {
  final _label = TextEditingController();
  final _passphrase = TextEditingController();
  final _repeat = TextEditingController();
  var _type = SshKeyType.ed25519;
  GeneratedKey? _generated;
  var _saving = false;
  var _obscured = true;

  @override
  void dispose() {
    // Cleared before disposal: a controller's text is a String nobody can
    // wipe, but there is no reason to keep a reference to it either.
    _passphrase.clear();
    _repeat.clear();
    _label.dispose();
    _passphrase.dispose();
    _repeat.dispose();
    super.dispose();
  }

  bool get _mismatch =>
      _passphrase.text.isNotEmpty && _passphrase.text != _repeat.text;

  bool get _canGenerate =>
      _label.text.trim().isNotEmpty && !_mismatch && !_saving;

  Future<void> _generate() async {
    final label = _label.text.trim();
    if (!_canGenerate) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);

    final passphrase = _passphrase.text.isEmpty ? null : _passphrase.text;

    try {
      // The comment is what shows beside the key in a server's
      // `authorized_keys` months from now, when someone is deciding whether
      // it is still needed. A label the user chose beats `user@device`.
      final key = await ref.read(keyGeneratorProvider)(
        _type,
        comment: label,
        passphrase: passphrase,
      );
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
              // The passphrase itself is not saved. Connecting asks for it,
              // with the usual offer to remember it — which is the point of
              // setting one.
              hasPassphrase: key.isEncrypted,
              origin: IdentityOrigin.generated,
              createdAt: now,
              updatedAt: now,
            ),
            privateKey: key.privateKey,
          );

      if (mounted) setState(() => _generated = key);
    } on Object catch (error, stackTrace) {
      ErrorLogger.instance.record(error, stackTrace, source: 'keygen');
      if (mounted) {
        setState(() => _saving = false);
        context.toast(l10n.keysGenerateFailed, isError: true);
      }
    }
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
      child: SingleChildScrollView(
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
              ..._form(l10n, theme)
            else
              ..._result(l10n, theme, generated),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(AppLocalizations l10n, SshKeyType type) =>
      switch (type) {
        SshKeyType.ed25519 => l10n.keysTypeEd25519,
        SshKeyType.ecdsaP256 => l10n.keysTypeEcdsaP256,
        SshKeyType.ecdsaP384 => l10n.keysTypeEcdsaP384,
        SshKeyType.rsa3072 => l10n.keysTypeRsa3072,
        SshKeyType.rsa4096 => l10n.keysTypeRsa4096,
      };

  List<Widget> _form(AppLocalizations l10n, ThemeData theme) => [
    TextField(
      key: const ValueKey('generate-label'),
      controller: _label,
      autofocus: true,
      enabled: !_saving,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: l10n.keysGenerateLabel),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: Spacing.md),
    DropdownButtonFormField<SshKeyType>(
      key: const ValueKey('generate-type'),
      isExpanded: true,
      initialValue: _type,
      decoration: InputDecoration(
        labelText: l10n.keysTypeLabel,
        helperText: l10n.keysTypeHelp,
        helperMaxLines: 3,
      ),
      items: [
        for (final type in SshKeyType.values)
          DropdownMenuItem(value: type, child: Text(_typeLabel(l10n, type))),
      ],
      onChanged: _saving
          ? null
          : (type) => setState(() => _type = type ?? SshKeyType.ed25519),
    ),
    const SizedBox(height: Spacing.md),
    TextField(
      key: const ValueKey('generate-passphrase'),
      controller: _passphrase,
      enabled: !_saving,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.keysPassphraseLabel,
        helperText: l10n.keysPassphraseHelp,
        helperMaxLines: 3,
        suffixIcon: IconButton(
          icon: Icon(_obscured ? PiconsRegular.eye : PiconsRegular.eyeSlash),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      onChanged: (_) => setState(() {}),
    ),
    if (_passphrase.text.isNotEmpty) ...[
      const SizedBox(height: Spacing.md),
      TextField(
        key: const ValueKey('generate-passphrase-repeat'),
        controller: _repeat,
        enabled: !_saving,
        obscureText: _obscured,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: l10n.keysPassphraseRepeat,
          errorText: _repeat.text.isNotEmpty && _mismatch
              ? l10n.keysPassphraseMismatch
              : null,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _generate(),
      ),
    ],
    const SizedBox(height: Spacing.lg),
    if (_saving) ...[
      const LinearProgressIndicator(),
      const SizedBox(height: Spacing.sm),
      Text(
        _type.isSlow ? l10n.keysGeneratingSlow : l10n.keysGenerating,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: Spacing.md),
    ],
    Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        key: const ValueKey('generate-submit'),
        onPressed: _canGenerate ? _generate : null,
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
    const SizedBox(height: Spacing.sm),
    SelectableText(
      generated.fingerprint,
      style: Mono.apply(theme.textTheme.bodySmall)
          .copyWith(color: theme.colorScheme.onSurfaceVariant),
    ),
    const SizedBox(height: Spacing.lg),
    OverflowBar(
      // Buttons stack instead of overflowing when a narrow phone and a long
      // label do not fit side by side.
      alignment: MainAxisAlignment.end,
      spacing: Spacing.sm,
      overflowAlignment: OverflowBarAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
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
