import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/ssh/ssh_algorithm_policy.dart';
import '../../core/ssh/ssh_target.dart';
import '../../core/theme/terminal_theme.dart';
import '../../core/theme/terminal_theme_presets.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../core/settings/app_settings.dart';
import '../keys/keys_controller.dart';
import 'domain/connection_string.dart';
import 'domain/host_env.dart';
import 'domain/host_group.dart';
import 'domain/host_tags.dart';
import 'domain/ssh_host.dart';
import 'hosts_controller.dart';
import '../settings/widgets/terminal_theme_preview.dart';
import 'widgets/env_vars_editor.dart';
import 'widgets/group_actions.dart';
import 'widgets/tag_editor.dart';

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
  final _tagInput = TextEditingController();
  final _notes = TextEditingController();
  final _keepalive = TextEditingController(text: '30');

  String? _groupId;
  var _tags = <String>[];

  /// This host's terminal font size; null follows the app setting.
  double? _fontSize;

  /// This host's terminal colour preset; null follows the app setting. Kept
  /// verbatim from the row, so an id this build does not know survives an
  /// edit of some other field.
  String? _terminalTheme;

  /// The environment variables as last loaded, and as edited since. See
  /// [EnvVarsEditor].
  Map<String, String> _envInitial = const {};
  List<(String, String)> _envPairs = const [];

  /// Open when editing a host that already has a group, tags or notes.
  var _organiseOpen = false;

  SshAuthMethod _auth = SshAuthMethod.publicKey;
  String? _identityId;
  String? _jumpHostId;
  var _allowLegacy = false;
  var _forwardAgent = false;
  var _tmuxMode = HostTmuxMode.followDefault;
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
    _tagInput.dispose();
    _notes.dispose();
    _keepalive.dispose();
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
    _forwardAgent = host.forwardAgent;
    _tmuxMode = host.tmuxMode;
    _groupId = host.groupId;
    _tags = [...host.tags];
    _notes.text = host.notes ?? '';
    _keepalive.text = '${host.keepaliveSeconds}';
    _fontSize = host.fontSize;
    _terminalTheme = host.terminalTheme;
    _envInitial = host.envVars;
    _envPairs = [for (final e in host.envVars.entries) (e.key, e.value)];
    _organiseOpen =
        host.groupId != null || host.tags.isNotEmpty || host.hasNotes;
  }

  /// The tags to save: the chips, plus anything typed and not yet committed.
  ///
  /// Typing `prod` and pressing Save is a perfectly clear request; making it
  /// vanish because Enter was not pressed first would be the form's fault.
  List<String> get _tagsToSave =>
      HostTags.normalize([..._tags, ..._tagInput.text.split(',')]);

  Future<void> _pickGroup(String? value) async {
    if (value != _newGroupValue) {
      setState(() => _groupId = value);
      return;
    }
    final created = await createGroupFlow(context, ref);
    if (!mounted) return;
    // Cancelling "New group…" leaves the previous choice, not the sentinel.
    setState(() => _groupId = created?.id ?? _groupId);
  }

  /// The dropdown value standing for "create one". Not a valid group id —
  /// generated ids are lowercase alphanumerics — so it cannot collide.
  static const _newGroupValue = '+new';

  /// An hour. Anything longer is not keeping a connection alive; it is
  /// hoping.
  static const _maxKeepalive = 3600;

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
    // The variables are checked here too: folded away inside Advanced, their
    // fields are not in the form, and a bad name must not be saved unseen.
    final envProblem = [
      for (var i = 0; i < _envPairs.length; i++)
        HostEnv.problemAt(_envPairs, i),
    ].any((problem) => problem != null);
    if (envProblem) {
      setState(() => _advancedOpen = true);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _formKey.currentState?.validate(),
      );
      return;
    }
    final envVars = HostEnv.fromPairs(_envPairs);
    final now = DateTime.now().toUtc();
    final existing = _existing;
    final notes = _notes.text.trim();
    // Parsed defensively rather than trusting the validator: a folded
    // disclosure takes its fields out of the form, so a bad value typed and
    // then hidden is never validated.
    final keepalive =
        int.tryParse(_keepalive.text.trim())?.clamp(0, _maxKeepalive) ??
        existing?.keepaliveSeconds ??
        30;
    final tags = _tagsToSave;

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
            forwardAgent: _forwardAgent,
            tmuxMode: _tmuxMode,
            startupCommand: _startup.text.trim().isEmpty
                ? null
                : _startup.text.trim(),
            groupId: _groupId,
            tags: tags,
            notes: notes.isEmpty ? null : notes,
            keepaliveSeconds: keepalive,
            envVars: envVars,
            fontSize: _fontSize,
            terminalTheme: _terminalTheme,
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
            forwardAgent: _forwardAgent,
            tmuxMode: _tmuxMode,
            startupCommand: _startup.text.trim().isEmpty
                ? null
                : _startup.text.trim(),
            clearStartupCommand: _startup.text.trim().isEmpty,
            groupId: _groupId,
            clearGroupId: _groupId == null,
            tags: tags,
            notes: notes.isEmpty ? null : notes,
            clearNotes: notes.isEmpty,
            keepaliveSeconds: keepalive,
            fontSize: _fontSize,
            clearFontSize: _fontSize == null,
            terminalTheme: _terminalTheme,
            clearTerminalTheme: _terminalTheme == null,
            envVars: envVars,
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
    final groups = ref.watch(hostGroupsProvider).value ?? const <HostGroup>[];

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
              // Its own fold, ahead of Advanced: where a server is filed and
              // what it is tagged is organisation, not configuration, and
              // someone tidying thirty hosts should not wade through auth
              // settings to get to it.
              _Advanced(
                // Re-keyed once the host has loaded: `initiallyExpanded` is
                // read on first build, which for an existing host happens
                // before its row arrives.
                key: ValueKey('organise-$_loaded'),
                title: l10n.hostEditorOrganise,
                open: _organiseOpen,
                onChanged: (open) => setState(() => _organiseOpen = open),
                children: [
                  DropdownButtonFormField<String?>(
                    // Re-keyed on the choice so a group created from here is
                    // shown selected; `initialValue` is read once.
                    key: ValueKey('group-$_groupId-${groups.length}'),
                    isExpanded: true,
                    // A group deleted since this host was filed reads as none.
                    initialValue: groups.any((g) => g.id == _groupId)
                        ? _groupId
                        : null,
                    decoration: InputDecoration(
                      labelText: l10n.hostEditorGroup,
                      prefixIcon: const Icon(PiconsRegular.folderSimple),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(child: Text(l10n.hostEditorGroupNone)),
                      for (final group in groups)
                        DropdownMenuItem(
                          value: group.id,
                          child: Text(
                            group.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      DropdownMenuItem(
                        value: _newGroupValue,
                        child: Text(l10n.hostEditorGroupNew),
                      ),
                    ],
                    onChanged: _pickGroup,
                  ),
                  const SizedBox(height: Spacing.lg),
                  TagEditor(
                    tags: _tags,
                    controller: _tagInput,
                    suggestions: ref.watch(hostTagsProvider),
                    onChanged: (tags) => setState(() => _tags = tags),
                  ),
                  const SizedBox(height: Spacing.lg),
                  TextFormField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.hostEditorNotes,
                      hintText: l10n.hostEditorNotesHint,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              _Advanced(
                key: ValueKey('advanced-$_loaded'),
                title: l10n.hostEditorAdvanced,
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
                      initialValue: identities.any((i) => i.id == _identityId)
                          ? _identityId
                          : null,
                      decoration: InputDecoration(
                        labelText: l10n.hostEditorIdentity,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        // Null means "any", not "none" — it is what an imported
                        // host arrives with, and it works.
                        DropdownMenuItem(
                          child: Text(l10n.hostEditorIdentityAny),
                        ),
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
                  const SizedBox(height: Spacing.lg),
                  // Beside the startup command: the other thing this host
                  // puts into every new shell.
                  EnvVarsEditor(
                    key: ValueKey('env-$_loaded'),
                    initial: _envInitial,
                    onChanged: (pairs) => _envPairs = pairs,
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
                  SwitchListTile(
                    key: const Key('hostEditor.forwardAgent'),
                    value: _forwardAgent,
                    onChanged: (value) => setState(() => _forwardAgent = value),
                    title: Text(l10n.hostEditorForwardAgent),
                    subtitle: Text(
                      l10n.hostEditorForwardAgentHelp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    isThreeLine: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: Spacing.lg),
                  _TmuxModeChoice(
                    // Re-keyed once the host has loaded, like the other
                    // controls that read their value once.
                    key: ValueKey('tmux-$_loaded'),
                    value: _tmuxMode,
                    onChanged: (mode) => setState(() => _tmuxMode = mode),
                  ),
                  const SizedBox(height: Spacing.lg),
                  TextFormField(
                    controller: _keepalive,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.hostEditorKeepalive,
                      suffixText: l10n.hostEditorKeepaliveSuffix,
                      helperText: l10n.hostEditorKeepaliveHelp,
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final seconds = int.tryParse(value?.trim() ?? '');
                      if (seconds == null ||
                          seconds < 0 ||
                          seconds > _maxKeepalive) {
                        return l10n.hostEditorKeepaliveInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Spacing.md),
                  _FontSizeOverride(
                    value: _fontSize,
                    onChanged: (size) => setState(() => _fontSize = size),
                  ),
                  const SizedBox(height: Spacing.md),
                  _TerminalThemeOverride(
                    value: _terminalTheme,
                    onChanged: (id) => setState(() => _terminalTheme = id),
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
            style: Mono.apply(theme.textTheme.bodySmall)
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// An optional per-host terminal font size.
///
/// Off by default — following the app setting is right for nearly every host —
/// and the same smaller/larger steps as the Settings tile when on, so the two
/// controls for one idea look like one control.
class _FontSizeOverride extends ConsumerWidget {
  const _FontSizeOverride({required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appDefault = ref.watch(
      settingsControllerProvider.select((s) => s.terminalFontSize),
    );
    final size = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: size == null,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.hostEditorFontSize),
          subtitle: Text(
            l10n.hostEditorFontSizeDefault(
              l10n.terminalTextSizePoints(appDefault.round()),
            ),
          ),
          // Turning the default off starts from the default, so the first
          // thing the switch does is nothing visible — then the steps adjust.
          onChanged: (useDefault) => onChanged(useDefault ? null : appDefault),
        ),
        if (size != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(PiconsRegular.terminalWindow),
            title: Text(l10n.terminalTextSizePoints(size.round())),
            subtitle: Text(
              l10n.hostEditorFontSizeHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(PiconsRegular.magnifyingGlassMinus),
                  tooltip: l10n.terminalTextSizeSmaller,
                  onPressed: size <= AppSettings.minTerminalFontSize
                      ? null
                      : () => onChanged(size - 1),
                ),
                IconButton(
                  icon: const Icon(PiconsRegular.magnifyingGlassPlus),
                  tooltip: l10n.terminalTextSizeLarger,
                  onPressed: size >= AppSettings.maxTerminalFontSize
                      ? null
                      : () => onChanged(size + 1),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Whether this host's tabs are kept running on the server in tmux: the
/// app-wide setting (named, with what it currently is), or always, or never.
class _TmuxModeChoice extends ConsumerWidget {
  const _TmuxModeChoice({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final HostTmuxMode value;
  final ValueChanged<HostTmuxMode> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final globalOn = ref.watch(
      settingsControllerProvider.select((s) => s.keepSessionsOnServer),
    );

    return DropdownButtonFormField<HostTmuxMode>(
      key: const Key('hostEditor.tmuxMode'),
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: l10n.hostEditorTmuxMode,
        helperText: l10n.hostEditorTmuxModeHelp,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(
          value: HostTmuxMode.followDefault,
          child: Text(
            globalOn
                ? l10n.hostEditorTmuxModeDefaultOn
                : l10n.hostEditorTmuxModeDefaultOff,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: HostTmuxMode.always,
          child: Text(l10n.hostEditorTmuxModeAlways),
        ),
        DropdownMenuItem(
          value: HostTmuxMode.never,
          child: Text(l10n.hostEditorTmuxModeNever),
        ),
      ],
      onChanged: (mode) {
        if (mode != null) onChanged(mode);
      },
    );
  }
}

/// An optional per-host terminal colour scheme.
///
/// The obvious use is telling production from staging at a glance. The
/// "use default" entry names the default, so the choice is between two
/// things the user can see rather than between a theme and a mystery.
class _TerminalThemeOverride extends ConsumerWidget {
  const _TerminalThemeOverride({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appDefault = TerminalThemePresets.byId(
      ref.watch(settingsControllerProvider.select((s) => s.terminalThemeId)),
    );

    Widget item(TerminalThemePreset preset, String label) => Row(
      children: [
        TerminalThemeSwatch(preset: preset),
        const SizedBox(width: Spacing.md),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    return DropdownButtonFormField<String?>(
      isExpanded: true,
      // An id this build does not know shows as the default, which is what
      // the terminal draws with; it is only replaced if a choice is made.
      initialValue: TerminalThemePresets.isKnown(value) ? value : null,
      decoration: InputDecoration(
        labelText: l10n.hostEditorTerminalTheme,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String?>(
          child: item(
            appDefault,
            l10n.hostEditorTerminalThemeDefault(appDefault.name),
          ),
        ),
        for (final preset in TerminalThemePresets.all)
          DropdownMenuItem<String?>(
            value: preset.id,
            child: item(preset, preset.name),
          ),
      ],
      onChanged: onChanged,
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
    required this.title,
    super.key,
    required this.open,
    required this.onChanged,
    required this.children,
  });

  final String title;
  final bool open;
  final ValueChanged<bool> onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: children,
      ),
    );
  }
}
