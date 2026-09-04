import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/ssh/ssh_algorithm_policy.dart';
import '../../core/ssh/ssh_target.dart';
import '../../core/theme/terminal_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../keys/keys_controller.dart';
import 'domain/connection_string.dart';
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

  /// The one field most hosts ever need.
  ///
  /// Nobody has a host, a user and a port in three separate places — they have
  /// a line from a wiki, a terminal or a colleague. This takes that line, and
  /// the fields below show what was read out of it so nothing is guessed
  /// behind the user's back.
  final _connection = TextEditingController();
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

  /// Open by default when editing, closed when adding.
  ///
  /// A new host is usually one line and a Save; an existing one is being
  /// opened *because* something in here needs changing.
  var _advancedOpen = false;

  /// Whether the label has been typed in by hand.
  ///
  /// Until it has, it follows the address — which is what people would have
  /// typed anyway. Once they edit it, it is theirs and nothing overwrites it.
  var _labelEdited = false;

  /// Set when a pasted command carried `-i`, so the screen can say the flag
  /// was ignored rather than quietly dropping it.
  String? _ignoredIdentityFile;

  @override
  void initState() {
    super.initState();
    // A new host starts with the key the user nominated. Most people have one
    // key and use it everywhere, so asking on every host is a question with
    // the same answer every time.
    //
    // Here rather than alongside the code that loads an existing host: that
    // waits for the list of *other* hosts to arrive, and which key a new host
    // starts with has nothing to do with them. Tying the two together meant a
    // slow list left the default unapplied.
    if (widget.hostId == null) {
      _identityId = ref.read(settingsControllerProvider).defaultIdentityId;
    }
  }

  @override
  void dispose() {
    _connection.dispose();
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
    _advancedOpen = true;
    _labelEdited = true;
    _connection.text = host.port == 22
        ? '${host.username}@${host.hostname}'
        : '${host.username}@${host.hostname}:${host.port}';
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

  /// Reads the connection field into the fields below it.
  ///
  /// Only ever *fills*, never blanks: a line that stops parsing halfway
  /// through being typed must not wipe a port the user set by hand. What it
  /// does overwrite is what it previously wrote, which is the whole point of
  /// the field.
  void _parseConnection(String text) {
    final parsed = parseConnection(text);
    setState(() {
      _ignoredIdentityFile = parsed?.identityFile;
      if (parsed == null) return;

      _hostname.text = parsed.hostname;
      if (parsed.username case final user? when user.isNotEmpty) {
        _username.text = user;
      }
      if (parsed.port case final port?) _port.text = '$port';
      if (!_labelEdited) _label.text = parsed.hostname;
    });
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
              // One field, because that is how the information arrives.
              TextFormField(
                controller: _connection,
                autocorrect: false,
                autofocus: widget.hostId == null,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.hostEditorConnection,
                  hintText: l10n.hostEditorConnectionHint,
                  helperText: l10n.hostEditorConnectionHelp,
                  helperMaxLines: 2,
                  prefixIcon: const Icon(PiconsRegular.hardDrives),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _parseConnection,
                validator: (value) => parseConnection(value ?? '') == null
                    ? l10n.hostEditorConnectionInvalid
                    : null,
              ),

              // What was read out of it, shown rather than hidden: a form that
              // silently decides where you are connecting is a form you cannot
              // check before pressing Save.
              if (_hostname.text.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                _ParsedSummary(
                  username: _username.text,
                  hostname: _hostname.text,
                  port: _port.text,
                ),
              ],

              if (_ignoredIdentityFile != null) ...[
                const SizedBox(height: Spacing.sm),
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
                        l10n.hostEditorIdentityFileIgnored,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: Spacing.lg),
              // Required, and asked for here rather than in Advanced: a
              // connection string without a user is common, and a required
              // field hidden behind a disclosure is a form that refuses to
              // save for a reason you cannot see.
              if (_username.text.trim().isEmpty)
                TextFormField(
                  controller: _username,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.hostEditorUsername,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: _required(l10n),
                ),

              const SizedBox(height: Spacing.md),
              _Advanced(
                open: _advancedOpen,
                onChanged: (open) => setState(() => _advancedOpen = open),
                children: [
                  TextFormField(
                    controller: _label,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: l10n.hostEditorLabel,
                      hintText: l10n.hostEditorLabelHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _labelEdited = true,
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
                          onChanged: (_) => setState(() {}),
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
                          onChanged: (_) => setState(() {}),
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
                  if (_username.text.trim().isNotEmpty)
                    TextFormField(
                      controller: _username,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.hostEditorUsername,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
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
                  // isExpanded: a dropdown sizes itself to its selected item, and
                  // a key or host with a descriptive name is wider than the pane
                  // it sits in. Without it the row overflows rather than the
                  // label ellipsising.
                  isExpanded: true,
                  // Only ever a value the list actually contains. A dropdown
                  // asserts on an id it has no item for, and there are two
                  // ordinary ways to get one: the default key from Settings
                  // while the list is still loading, and a key deleted since
                  // this host named it. Falling back to "any" is also what
                  // both of those now behave as.
                  initialValue:
                      identities.any((i) => i.id == _identityId)
                      ? _identityId
                      : null,
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

              const SizedBox(height: Spacing.lg),
              DropdownButtonFormField<String?>(
                // isExpanded: a dropdown sizes itself to its selected item, and
                // a key or host with a descriptive name is wider than the pane
                // it sits in. Without it the row overflows rather than the
                // label ellipsising.
                isExpanded: true,
                // Likewise: a jump host deleted since this one named it.
                initialValue:
                    allHosts.any(
                      (h) => h.id == _jumpHostId && h.id != widget.hostId,
                    )
                    ? _jumpHostId
                    : null,
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

/// What the app read out of the connection field, said back.
///
/// A form that silently decides where you are connecting is a form you cannot
/// check before pressing Save — and the shapes people paste are ambiguous
/// enough (`host:2222` is a port, `[::1]:22` is not a hostname called `[`)
/// that "it looked right in the box" is not the same as "it was understood".
class _ParsedSummary extends StatelessWidget {
  const _ParsedSummary({
    required this.username,
    required this.hostname,
    required this.port,
  });

  final String username;
  final String hostname;
  final String port;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = username.trim();
    final target = port.trim() == '22' || port.trim().isEmpty
        ? hostname
        : '$hostname:${port.trim()}';

    return Row(
      children: [
        Icon(
          PiconsRegular.arrowRight,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            user.isEmpty ? target : '$user@$target',
            style: Mono.apply(theme.textTheme.bodySmall).copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Everything most hosts never need, folded away.
///
/// A disclosure rather than a second screen: the settings in here are edited
/// while looking at the address they belong to, and a form that sends you
/// somewhere else to set a port is a form that has forgotten what it is for.
class _Advanced extends StatelessWidget {
  const _Advanced({
    required this.open,
    required this.onChanged,
    required this.children,
  });

  final bool open;
  final ValueChanged<bool> onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Theme(
      // The default divider lines make a bordered box inside a form of
      // bordered boxes.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: open,
        onExpansionChanged: onChanged,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: Spacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(
          l10n.hostEditorAdvanced,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: children,
      ),
    );
  }
}

