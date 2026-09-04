import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/ssh/ssh_algorithm_policy.dart';
import '../../core/ssh/ssh_target.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../keys/keys_controller.dart';
import 'domain/ssh_host.dart';
import 'hosts_controller.dart';

/// Add or edit one host.
class HostEditorScreen extends ConsumerStatefulWidget {
  const HostEditorScreen({this.hostId, this.embedded = false, super.key});

  /// Null for a new host.
  final String? hostId;

  /// True when this is a tab in the desktop workspace.
  ///
  /// The tab supplies the title and the way out, so the app bar keeps its
  /// actions — Save has nowhere else to go — and drops its leading control.
  /// Without that, `automaticallyImplyLeading` finds the shell's route and
  /// offers a back arrow that would pop the whole shell.
  final bool embedded;

  @override
  ConsumerState<HostEditorScreen> createState() => _HostEditorScreenState();
}

class _HostEditorScreenState extends ConsumerState<HostEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _hostname = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController();
  final _startup = TextEditingController();

  SshAuthMethod _auth = SshAuthMethod.publicKey;
  String? _identityId;
  String? _jumpHostId;
  var _allowLegacy = false;
  var _loaded = false;
  SshHost? _existing;

  @override
  void dispose() {
    _label.dispose();
    _hostname.dispose();
    _port.dispose();
    _username.dispose();
    _startup.dispose();
    super.dispose();
  }

  void _load(List<SshHost> hosts) {
    if (_loaded || widget.hostId == null) {
      _loaded = true;
      return;
    }
    final host = hosts.where((h) => h.id == widget.hostId).firstOrNull;
    if (host == null) return;
    _loaded = true;
    _existing = host;
    _label.text = host.label;
    _hostname.text = host.hostname;
    _port.text = '${host.port}';
    _username.text = host.username;
    _startup.text = host.startupCommand ?? '';
    _auth = host.authMethod;
    _identityId = host.identityId;
    _jumpHostId = host.jumpHostId;
    _allowLegacy = host.allowLegacyAlgorithms;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now().toUtc();
    final existing = _existing;

    final host = existing == null
        ? SshHost(
            id: _newId(),
            label: _label.text.trim(),
            hostname: _hostname.text.trim(),
            port: int.parse(_port.text.trim()),
            username: _username.text.trim(),
            authMethod: _auth,
            identityId: _auth == SshAuthMethod.publicKey ? _identityId : null,
            jumpHostId: _jumpHostId,
            allowLegacyAlgorithms: _allowLegacy,
            startupCommand: _startup.text.trim().isEmpty
                ? null
                : _startup.text.trim(),
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            label: _label.text.trim(),
            hostname: _hostname.text.trim(),
            port: int.parse(_port.text.trim()),
            username: _username.text.trim(),
            authMethod: _auth,
            identityId: _auth == SshAuthMethod.publicKey ? _identityId : null,
            clearIdentityId: _auth != SshAuthMethod.publicKey,
            jumpHostId: _jumpHostId,
            clearJumpHostId: _jumpHostId == null,
            allowLegacyAlgorithms: _allowLegacy,
            startupCommand: _startup.text.trim().isEmpty
                ? null
                : _startup.text.trim(),
            clearStartupCommand: _startup.text.trim().isEmpty,
            updatedAt: now,
          );

    await ref.read(hostsControllerProvider).save(host);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hostsAsync = ref.watch(hostsProvider);
    final identities = ref.watch(identitiesProvider).value ?? const [];

    hostsAsync.whenData(_load);
    final allHosts = hostsAsync.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        // The tab already carries the name. Repeating it here would say the
        // same word twice, forty pixels apart.
        title: widget.embedded
            ? null
            : Text(
                widget.hostId == null
                    ? l10n.hostEditorNew
                    : l10n.hostEditorEdit,
              ),
        actions: [
          TextButton(onPressed: _save, child: Text(l10n.hostEditorSave)),
        ],
      ),
      body: ContentWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              TextFormField(
                controller: _label,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: l10n.hostEditorLabel,
                  hintText: l10n.hostEditorLabelHint,
                  border: const OutlineInputBorder(),
                ),
                validator: _required(l10n),
              ),
              const SizedBox(height: Spacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _hostname,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.hostEditorHostname,
                        hintText: l10n.hostEditorHostnameHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: _required(l10n),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.hostEditorPort,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final port = int.tryParse(value?.trim() ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return l10n.hostEditorPortInvalid;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),
              TextFormField(
                controller: _username,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.hostEditorUsername,
                  border: const OutlineInputBorder(),
                ),
                validator: _required(l10n),
              ),

              SectionLabel(l10n.hostEditorAuth),
              SegmentedButton<SshAuthMethod>(
                segments: [
                  ButtonSegment(
                    value: SshAuthMethod.publicKey,
                    label: Text(l10n.hostEditorAuthKey),
                    icon: const Icon(PiconsRegular.key),
                  ),
                  ButtonSegment(
                    value: SshAuthMethod.password,
                    label: Text(l10n.hostEditorAuthPasswordOnly),
                    icon: const Icon(PiconsRegular.lockSimple),
                  ),
                ],
                selected: {_auth},
                onSelectionChanged: (value) =>
                    setState(() => _auth = value.first),
              ),
              const SizedBox(height: Spacing.sm),
              // Says what each choice actually does. The pair of buttons on
              // its own implies that naming a key and using a password are the
              // only options, which leaves the commonest case of all — "use
              // whichever of my keys this server accepts" — with no name, and
              // is what sent nine of ten imported hosts to a password prompt.
              Text(
                _auth == SshAuthMethod.publicKey
                    ? l10n.hostEditorAuthKeyHint
                    : l10n.hostEditorAuthPasswordHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_auth == SshAuthMethod.publicKey) ...[
                const SizedBox(height: Spacing.lg),
                DropdownButtonFormField<String?>(
                  initialValue: _identityId,
                  decoration: InputDecoration(
                    labelText: l10n.hostEditorIdentity,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    // Null means "any", not "none" — it is what an imported
                    // host arrives with, and it works.
                    DropdownMenuItem(child: Text(l10n.hostEditorIdentityAny)),
                    for (final identity in identities)
                      DropdownMenuItem(
                        value: identity.id,
                        child: Text(identity.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => _identityId = value),
                ),
              ],

              SectionLabel(l10n.hostEditorAdvanced),
              DropdownButtonFormField<String?>(
                initialValue: _jumpHostId,
                decoration: InputDecoration(
                  labelText: l10n.hostEditorJump,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(child: Text(l10n.hostEditorJumpNone)),
                  for (final other in allHosts)
                    // A host cannot jump through itself. The repository breaks
                    // the cycle anyway, but offering it in a picker invites a
                    // mistake there is no reason to allow.
                    if (other.id != widget.hostId)
                      DropdownMenuItem(
                        value: other.id,
                        child: Text(other.label),
                      ),
                ],
                onChanged: (value) => setState(() => _jumpHostId = value),
              ),
              const SizedBox(height: Spacing.lg),
              TextFormField(
                controller: _startup,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.hostEditorStartup,
                  hintText: l10n.hostEditorStartupHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.sm),
              SwitchListTile(
                value: _allowLegacy,
                onChanged: (value) => setState(() => _allowLegacy = value),
                title: Text(l10n.hostEditorLegacy),
                // The full warning, not a shortened one: the user is agreeing
                // to a real downgrade, and this is the moment they decide.
                subtitle: Text(
                  SshAlgorithmPolicy.legacyWarning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                isThreeLine: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? Function(String?) _required(AppLocalizations l10n) =>
      (value) => (value == null || value.trim().isEmpty)
      ? l10n.hostEditorRequired
      : null;

  static final _random = Random.secure();

  static String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      20,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}
