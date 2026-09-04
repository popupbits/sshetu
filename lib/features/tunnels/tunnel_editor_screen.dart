import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../hosts/hosts_controller.dart';
import 'domain/tunnel.dart';
import 'tunnels_controller.dart';

/// Add or edit one port forward.
class TunnelEditorScreen extends ConsumerStatefulWidget {
  const TunnelEditorScreen({
    this.tunnelId,
    this.hostId,
    this.embedded = false,
    super.key,
  });

  /// Null for a new forward.
  final String? tunnelId;

  /// Preselects the host when adding — the ordinary way in, since the list
  /// screen always offers "add" from inside one host's section.
  final String? hostId;

  /// True when this is a tab in the desktop workspace.
  ///
  /// The tab supplies the title and the way out, so the app bar keeps its
  /// actions — Save has nowhere else to go — and drops its leading control.
  /// Without that, `automaticallyImplyLeading` finds the shell's route and
  /// offers a back arrow that would pop the whole shell.
  final bool embedded;

  @override
  ConsumerState<TunnelEditorScreen> createState() => _TunnelEditorScreenState();
}

class _TunnelEditorScreenState extends ConsumerState<TunnelEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _listenHost = TextEditingController(text: Tunnel.defaultListenHost);
  final _listenPort = TextEditingController();

  /// Defaults to loopback, because that is nearly always the answer.
  ///
  /// A service you need a tunnel to reach is, by definition, one that is not
  /// reachable directly — which usually means it is bound to its own machine's
  /// loopback. Starting the field empty made every forward begin by typing the
  /// same four numbers.
  final _targetHost = TextEditingController(text: Tunnel.defaultListenHost);
  final _targetPort = TextEditingController();

  TunnelKind _kind = TunnelKind.local;
  String? _selectedHostId;
  var _autoStart = false;
  var _loaded = false;
  Tunnel? _existing;

  @override
  void initState() {
    super.initState();
    _selectedHostId = widget.hostId;
  }

  @override
  void dispose() {
    _label.dispose();
    _listenHost.dispose();
    _listenPort.dispose();
    _targetHost.dispose();
    _targetPort.dispose();
    super.dispose();
  }

  void _load(List<Tunnel> tunnels) {
    if (_loaded || widget.tunnelId == null) {
      _loaded = true;
      return;
    }
    final tunnel = tunnels.where((t) => t.id == widget.tunnelId).firstOrNull;
    if (tunnel == null) return;
    _loaded = true;
    _existing = tunnel;
    _label.text = tunnel.label;
    _listenHost.text = tunnel.listenHost;
    _listenPort.text = '${tunnel.listenPort}';
    _targetHost.text = tunnel.targetHost ?? Tunnel.defaultListenHost;
    _targetPort.text = tunnel.targetPort == null ? '' : '${tunnel.targetPort}';
    _kind = tunnel.kind;
    _selectedHostId = tunnel.hostId;
  }

  /// A name for a forward the user did not name.
  ///
  /// The column is NOT NULL and a list of rows all called "" is unusable, but
  /// making the user invent a label for `5432 → db:5432` is asking them to
  /// name something that already describes itself.
  String _labelOrDefault() {
    final typed = _label.text.trim();
    return typed.isEmpty ? _defaultLabel() : typed;
  }

  String _defaultLabel() {
    final port = _listenPort.text.trim();
    return switch (_kind) {
      TunnelKind.socks => 'SOCKS $port',
      _ => '$port → ${_targetHost.text.trim()}:${_targetPort.text.trim()}',
    };
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final hostId = _selectedHostId;
    if (hostId == null) return;

    final now = DateTime.now().toUtc();
    final existing = _existing;
    final needsTarget = _kind.requiresTarget;

    final tunnel = existing == null
        ? Tunnel(
            id: _newId(),
            hostId: hostId,
            label: _labelOrDefault(),
            kind: _kind,
            listenHost: _listenHost.text.trim(),
            listenPort: int.parse(_listenPort.text.trim()),
            targetHost: needsTarget ? _targetHost.text.trim() : null,
            targetPort: needsTarget ? int.parse(_targetPort.text.trim()) : null,
            autoStart: _autoStart,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            label: _labelOrDefault(),
            kind: _kind,
            listenHost: _listenHost.text.trim(),
            listenPort: int.parse(_listenPort.text.trim()),
            targetHost: needsTarget ? _targetHost.text.trim() : null,
            clearTargetHost: !needsTarget,
            targetPort: needsTarget ? int.parse(_targetPort.text.trim()) : null,
            clearTargetPort: !needsTarget,
            autoStart: _autoStart,
            updatedAt: now,
          );

    await ref.read(tunnelsControllerProvider).save(tunnel);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tunnelsAsync = ref.watch(tunnelsProvider);
    final hosts = ref.watch(hostsProvider).value ?? const [];

    tunnelsAsync.whenData(_load);
    final isNew = widget.tunnelId == null;
    final needsTarget = _kind.requiresTarget;
    final isLoopback = Tunnel.isLoopbackHost(_listenHost.text.trim());

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        // The tab already carries the name. Repeating it here would say the
        // same word twice, forty pixels apart.
        title: widget.embedded
            ? null
            : Text(isNew ? l10n.tunnelEditorNew : l10n.tunnelEditorEdit),
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
              // Always editable. This was a read-only display once a host
              // was set, on the reasoning that the screen is always reached
              // from a host that already knows itself — but picking the wrong
              // one then had no remedy except starting over, and a field that
              // looks like a field and does nothing when tapped reads as
              // broken rather than as deliberate.
              DropdownButtonFormField<String?>(
                // isExpanded: a dropdown sizes itself to its selected item, and
                // a key or host with a descriptive name is wider than the pane
                // it sits in. Without it the row overflows rather than the
                // label ellipsising.
                isExpanded: true,
                initialValue: _selectedHostId,
                decoration: InputDecoration(
                  labelText: l10n.tunnelEditorHost,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final host in hosts)
                    DropdownMenuItem(value: host.id, child: Text(host.label)),
                ],
                onChanged: (value) => setState(() => _selectedHostId = value),
                validator: (value) =>
                    value == null ? l10n.hostEditorRequired : null,
              ),
              const SizedBox(height: Spacing.lg),

              // What you want, in a sentence — not "local/remote/dynamic",
              // which are the flags `ssh` takes and mean nothing until you
              // already know the answer. The direction is the only genuinely
              // hard part of port forwarding, so it is asked first, in words,
              // and everything after it adapts.
              SectionLabel(l10n.tunnelWhat),
              _KindChoices(
                selected: _kind,
                onSelected: _selectKind,
                choices: [
                  (
                    kind: TunnelKind.local,
                    icon: PiconsRegular.arrowLeft,
                    title: l10n.tunnelLocalPlain,
                    body: l10n.tunnelLocalPlainBody,
                  ),
                  (
                    kind: TunnelKind.remote,
                    icon: PiconsRegular.arrowRight,
                    title: l10n.tunnelRemotePlain,
                    body: l10n.tunnelRemotePlainBody,
                  ),
                  (
                    kind: TunnelKind.socks,
                    icon: PiconsRegular.globeSimple,
                    title: l10n.tunnelSocksPlain,
                    body: l10n.tunnelSocksPlainBody,
                  ),
                ],
              ),

              const SizedBox(height: Spacing.lg),
              TextFormField(
                controller: _listenPort,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  // Which side the port is on depends on the direction, and
                  // saying "listen port" instead leaves the user to work that
                  // out from the word "listen".
                  labelText: _kind == TunnelKind.remote
                      ? l10n.tunnelPortThere
                      : l10n.tunnelPortHere,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: _portValidator(l10n),
              ),

              if (needsTarget) ...[
                const SizedBox(height: Spacing.lg),
                SectionLabel(
                  _kind == TunnelKind.local
                      ? l10n.tunnelServiceThere
                      : l10n.tunnelServiceHere,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _targetHost,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l10n.tunnelAddressField,
                          hintText: l10n.tunnelEditorTargetHostHint,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: _required(l10n),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _targetPort,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.tunnelPortField,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: _portValidator(l10n),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: Spacing.lg),
              _Preview(
                kind: _kind,
                listenPort: _listenPort.text,
                targetHost: _targetHost.text,
                targetPort: _targetPort.text,
                hostLabel: hosts
                    .where((h) => h.id == _selectedHostId)
                    .firstOrNull
                    ?.label,
              ),

              // Everything below is either rarely changed or actively
              // dangerous, and putting it beside the two fields that matter is
              // what made this screen read as a network appliance rather than
              // a thing you use.
              const SizedBox(height: Spacing.sm),
              ExpansionTile(
                title: Text(l10n.tunnelAdvanced),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: Spacing.md),
                children: [
                  TextFormField(
                    controller: _label,
                    decoration: InputDecoration(
                      labelText: l10n.tunnelNameOptional,
                      hintText: l10n.tunnelNameHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  TextFormField(
                    controller: _listenHost,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: _kind == TunnelKind.remote
                          ? l10n.tunnelBindThere
                          : l10n.tunnelBindHere,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: _required(l10n),
                  ),
                  if (!isLoopback) ...[
                    const SizedBox(height: Spacing.sm),
                    _WarningBanner(text: l10n.tunnelEditorNotLoopback),
                  ],
                  SwitchListTile(
                    value: _autoStart,
                    onChanged: (value) => setState(() => _autoStart = value),
                    title: Text(l10n.tunnelEditorAutoStart),
                    subtitle: Text(l10n.tunnelEditorAutoStartHint),
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

  /// Switching direction rewrites the defaults that go with it.
  ///
  /// The port a remote forward listens on is on the *server*, so a loopback
  /// bind address that was right for a local forward is now describing a
  /// different machine. Leaving the old value in place is how someone ends up
  /// binding the wrong side without ever seeing the field that did it.
  void _selectKind(TunnelKind kind) {
    setState(() {
      _kind = kind;
      if (_listenHost.text.trim().isEmpty ||
          Tunnel.isLoopbackHost(_listenHost.text.trim())) {
        _listenHost.text = '127.0.0.1';
      }
    });
  }

  String? Function(String?) _required(AppLocalizations l10n) =>
      (value) => (value == null || value.trim().isEmpty)
      ? l10n.hostEditorRequired
      : null;

  String? Function(String?) _portValidator(AppLocalizations l10n) => (value) {
    final port = int.tryParse(value?.trim() ?? '');
    return Tunnel.isValidPort(port) ? null : l10n.hostEditorPortInvalid;
  };

  static final _random = Random.secure();

  static String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      20,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}

/// The forward's host, shown but not editable — see the comment where this
/// is used.
class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PiconsRegular.shieldWarning, size: 18, color: scheme.error),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// One direction, stated as a sentence.
///
/// A card rather than a segment of a SegmentedButton: the choice needs a line
/// of explanation under it, and "local / remote / dynamic" squeezed into three
/// segments is exactly the labelling that makes port forwarding feel like
/// something only sysadmins do.
class _KindChoice extends StatelessWidget {
  const _KindChoice({
    required this.kind,
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onSelected,
  });

  final TunnelKind kind;
  final TunnelKind selected;
  final IconData icon;
  final String title;
  final String body;
  final void Function(TunnelKind) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = kind == selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: isSelected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: () => onSelected(kind),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the forward will actually do, in a sentence, as it is being typed.
///
/// Port forwarding is the one feature where people reliably get the direction
/// backwards and only find out when nothing connects. Saying it back in plain
/// words, live, is cheaper than any amount of field labelling.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.kind,
    required this.listenPort,
    required this.targetHost,
    required this.targetPort,
    required this.hostLabel,
  });

  final TunnelKind kind;
  final String listenPort;
  final String targetHost;
  final String targetPort;

  /// The server's name, so the sentence can say *which* machine each side is.
  ///
  /// Without it the preview read "…reaches 127.0.0.1:3000, as seen from the
  /// server", where the address belongs to the server but the only machine
  /// named in the sentence was this one. Naming both ends is the difference
  /// between a sentence that clarifies and one that has to be decoded.
  final String? hostLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final port = listenPort.trim();
    if (port.isEmpty) return const SizedBox.shrink();

    final listen = 'localhost:$port';
    final target = '${targetHost.trim()}:${targetPort.trim()}';
    final needsTarget = kind.requiresTarget;
    if (needsTarget &&
        (targetHost.trim().isEmpty || targetPort.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    final server = hostLabel ?? l10n.tunnelPreviewServerFallback;
    final text = switch (kind) {
      TunnelKind.local => l10n.tunnelPreviewLocal(listen, target, server),
      TunnelKind.remote => l10n.tunnelPreviewRemote(listen, server, target),
      TunnelKind.socks => l10n.tunnelPreviewSocks(listen, server),
    };

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PiconsRegular.info, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// The three directions, laid out to fit.
///
/// Stacked they read as a list of sentences, which is right on a phone and in
/// a narrow pane. Given room they sit side by side, because three short cards
/// in a column of empty space make the choice look longer than it is — and
/// this is a choice people find hard enough already without it appearing to
/// have more to it than three options.
class _KindChoices extends StatelessWidget {
  const _KindChoices({
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final List<
    ({TunnelKind kind, IconData icon, String title, String body})
  >
  choices;
  final TunnelKind selected;
  final void Function(TunnelKind) onSelected;

  /// Below this, three cards side by side are three columns of one word each.
  static const double _sideBySide = 720;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          for (final choice in choices)
            _KindChoice(
              kind: choice.kind,
              selected: selected,
              icon: choice.icon,
              title: choice.title,
              body: choice.body,
              onSelected: onSelected,
            ),
        ];

        if (constraints.maxWidth < _sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: Spacing.sm),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

