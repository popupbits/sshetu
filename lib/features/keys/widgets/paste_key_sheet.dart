import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/ssh/private_key_inspector.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/ssh_identity.dart';
import '../keys_controller.dart';

/// Adds a private key by pasting it.
///
/// The route in when a key arrives as text — a password manager's secure
/// note, a message from a colleague, a `cat` in another terminal — rather
/// than as a file. On a phone that is most of the time.
///
/// The key is read **before** it is saved, and the derived public key and
/// fingerprint are shown for the user to check: a paste is the least reliable
/// way a key travels, and "this is the key you meant" is worth a glance while
/// the text is still on screen. An encrypted key asks for its passphrase only
/// to prove it and derive the public half; the key is stored still sealed,
/// and the passphrase is not kept.
///
/// Nothing here logs, toasts or reports the text. Every failure is one of
/// [KeyProblem]'s fixed messages.
Future<void> showPasteKeySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const PasteKeySheet(),
  );
}

/// The sheet's body. Public for widget tests; open it with
/// [showPasteKeySheet].
class PasteKeySheet extends ConsumerStatefulWidget {
  const PasteKeySheet({super.key});

  @override
  ConsumerState<PasteKeySheet> createState() => _PasteKeySheetState();
}

class _PasteKeySheetState extends ConsumerState<PasteKeySheet> {
  final _key = TextEditingController();
  final _passphrase = TextEditingController();
  final _label = TextEditingController();

  InspectedKey? _inspected;
  KeyProblem? _problem;
  String? _duplicateOf;
  var _askPassphrase = false;
  var _busy = false;
  var _obscured = true;

  @override
  void dispose() {
    // Dropped as soon as the sheet is: there is no reason to keep a
    // reference to key material or a passphrase a moment longer.
    _key.clear();
    _passphrase.clear();
    _key.dispose();
    _passphrase.dispose();
    _label.dispose();
    super.dispose();
  }

  void _edited() => setState(() {
    _inspected = null;
    _problem = null;
    _duplicateOf = null;
  });

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
      _duplicateOf = null;
    });

    final result = await ref.read(keyInspectorProvider)(
      _key.text,
      passphrase: _askPassphrase ? _passphrase.text : null,
    );
    if (!mounted) return;

    final key = result.key;
    String? duplicateOf;
    if (key != null) {
      final existing = await ref.read(identitiesProvider.future);
      duplicateOf = existing
          .where((i) => i.fingerprint == key.fingerprint)
          .firstOrNull
          ?.label;
      if (!mounted) return;
    }

    setState(() {
      _busy = false;
      _duplicateOf = duplicateOf;
      if (key != null && duplicateOf == null) {
        _inspected = key;
        if (_label.text.trim().isEmpty && key.comment.isNotEmpty) {
          _label.text = key.comment;
        }
      } else {
        _problem = result.problem;
        if (result.problem == KeyProblem.needsPassphrase) {
          _askPassphrase = true;
        }
      }
    });
  }

  Future<void> _save() async {
    final key = _inspected;
    final label = _label.text.trim();
    if (key == null || label.isEmpty || _busy) return;
    setState(() => _busy = true);

    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final now = DateTime.now().toUtc();

    try {
      await ref
          .read(identitiesControllerProvider)
          .save(
            SshIdentity(
              id: '${now.microsecondsSinceEpoch}',
              label: label,
              keyType: key.keyType,
              publicKey: key.publicKey,
              fingerprint: key.fingerprint,
              hasPassphrase: key.isEncrypted,
              origin: IdentityOrigin.imported,
              createdAt: now,
              updatedAt: now,
            ),
            privateKey: key.pem,
          );
    } on Object {
      // Not recorded to the error log: a vault error can carry the slot it
      // failed on, and this is the one screen where the text is a key.
      if (!mounted) return;
      setState(() => _busy = false);
      context.toast(l10n.keysPasteSaveFailed, isError: true);
      return;
    }

    if (!mounted) return;
    context.toast(l10n.importKeyAdded(label));
    navigator.pop();
  }

  String? _keyError(AppLocalizations l10n) {
    final duplicate = _duplicateOf;
    if (duplicate != null) return l10n.keysPasteDuplicate(duplicate);
    return switch (_problem) {
      KeyProblem.empty => l10n.keysPasteEmpty,
      KeyProblem.publicKey => l10n.keysPastePublicKey,
      KeyProblem.notAKey => l10n.keysPasteNotAKey,
      KeyProblem.unsupportedFormat => l10n.keysPasteUnsupported,
      KeyProblem.damaged => l10n.keysPasteDamaged,
      // Shown on the passphrase field instead.
      KeyProblem.needsPassphrase || KeyProblem.wrongPassphrase || null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final inspected = _inspected;
    final mono = Mono.apply(theme.textTheme.bodySmall);

    return Padding(
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
            Text(l10n.keysPasteTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.keysPasteBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              key: const ValueKey('paste-key-field'),
              controller: _key,
              autofocus: true,
              enabled: !_busy,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
              // Nothing to learn from a private key, and nothing a keyboard
              // should be allowed to remember.
              enableIMEPersonalizedLearning: false,
              style: mono,
              decoration: InputDecoration(
                labelText: l10n.keysPasteField,
                alignLabelWithHint: true,
                hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                errorText: _keyError(l10n),
                errorMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: l10n.keysPaste,
                  icon: const Icon(PiconsRegular.clipboardText),
                  onPressed: _busy
                      ? null
                      : () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          final text = data?.text;
                          if (text == null || !mounted) return;
                          _key.text = text;
                          _edited();
                        },
                ),
              ),
              onChanged: (_) => _edited(),
            ),
            if (_askPassphrase) ...[
              const SizedBox(height: Spacing.md),
              TextField(
                key: const ValueKey('paste-passphrase-field'),
                controller: _passphrase,
                enabled: !_busy,
                obscureText: _obscured,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(
                  labelText: l10n.keysPastePassphrase,
                  helperText: _problem == KeyProblem.needsPassphrase
                      ? l10n.keysPasteNeedsPassphrase
                      : l10n.keysPastePassphraseHelp,
                  helperMaxLines: 3,
                  errorText: _problem == KeyProblem.wrongPassphrase
                      ? l10n.keysPasteWrongPassphrase
                      : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscured ? PiconsRegular.eye : PiconsRegular.eyeSlash,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
                onChanged: (_) => _edited(),
                onSubmitted: (_) => _check(),
              ),
            ],
            const SizedBox(height: Spacing.md),
            TextField(
              key: const ValueKey('paste-label-field'),
              controller: _label,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.keysGenerateLabel),
              onChanged: (_) => setState(() {}),
            ),
            if (inspected != null) ...[
              const SizedBox(height: Spacing.lg),
              _Preview(inspected: inspected, mono: mono),
            ],
            const SizedBox(height: Spacing.lg),
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: Spacing.md),
            ],
            OverflowBar(
              // Buttons stack instead of overflowing when a narrow phone
              // and a long label do not fit side by side.
              alignment: MainAxisAlignment.end,
              spacing: Spacing.sm,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.actionCancel),
                ),
                if (inspected == null)
                  FilledButton.icon(
                    key: const ValueKey('paste-check'),
                    onPressed: _busy || _key.text.trim().isEmpty
                        ? null
                        : _check,
                    icon: const Icon(PiconsRegular.magnifyingGlass),
                    label: Text(l10n.keysPasteCheck),
                  )
                else
                  FilledButton.icon(
                    key: const ValueKey('paste-save'),
                    onPressed: _busy || _label.text.trim().isEmpty
                        ? null
                        : _save,
                    icon: const Icon(PiconsRegular.key),
                    label: Text(l10n.keysPasteSave),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the pasted key turned out to be, for the user to check before saving.
class _Preview extends StatelessWidget {
  const _Preview({required this.inspected, required this.mono});

  final InspectedKey inspected;
  final TextStyle mono;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      key: const ValueKey('paste-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              inspected.keyType,
              if (inspected.isEncrypted) l10n.keysEncrypted,
            ].join(' · '),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: Spacing.sm),
          Text(l10n.keysFingerprintHeading, style: muted),
          SelectableText(inspected.fingerprint, style: mono),
          const SizedBox(height: Spacing.sm),
          Text(l10n.keysPublicKeyHeading, style: muted),
          SelectableText(inspected.publicKey, style: mono, maxLines: 4),
        ],
      ),
    );
  }
}
