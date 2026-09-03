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
  const TunnelEditorScreen({this.tunnelId, this.hostId, super.key});

  /// Null for a new forward.
  final String? tunnelId;

  /// Preselects the host when adding — the ordinary way in, since the list
  /// screen always offers "add" from inside one host's section.
  final String? hostId;

  @override
  ConsumerState<TunnelEditorScreen> createState() => _TunnelEditorScreenState();
}

class _TunnelEditorScreenState extends ConsumerState<TunnelEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _listenHost = TextEditingController(text: Tunnel.defaultListenHost);
  final _listenPort = TextEditingController();
  final _targetHost = TextEditingController();
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
    _targetHost.text = tunnel.targetHost ?? '';
    _targetPort.text = tunnel.targetPort == null ? '' : '${tunnel.targetPort}';
    _kind = tunnel.kind;
    _selectedHostId = tunnel.hostId;
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
            label: _label.text.trim(),
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
            label: _label.text.trim(),
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
    final theme = Theme.of(context);
    final tunnelsAsync = ref.watch(tunnelsProvider);
    final hosts = ref.watch(hostsProvider).value ?? const [];

    tunnelsAsync.whenData(_load);
    final isNew = widget.tunnelId == null;
    final needsTarget = _kind.requiresTarget;
    final isLoopback = Tunnel.isLoopbackHost(_listenHost.text.trim());

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l10n.tunnelEditorNew : l10n.tunnelEditorEdit),
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
              // The host is fixed by how this screen was reached — from that
              // host's section on the list, or from the forward being
              // edited — never chosen here. Re-parenting a saved forward to a
              // different host would be indistinguishable from creating a new
              // one, so there is nothing to make editable; this is a
              // dropdown only as a defensive fallback for the case neither
              // supplied one.
              if (_selectedHostId != null)
                _HostDisplay(
                  label: hosts
                      .where((h) => h.id == _selectedHostId)
                      .firstOrNull
                      ?.label,
                )
              else
                DropdownButtonFormField<String?>(
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
              TextFormField(
                controller: _label,
                decoration: InputDecoration(
                  labelText: l10n.tunnelEditorLabel,
                  hintText: l10n.tunnelEditorLabelHint,
                  border: const OutlineInputBorder(),
                ),
                validator: _required(l10n),
              ),

              SectionLabel(l10n.tunnelEditorKind),
              SegmentedButton<TunnelKind>(
                segments: [
                  ButtonSegment(
                    value: TunnelKind.local,
                    label: Text(l10n.tunnelKindLocal),
                    icon: const Icon(PiconsRegular.arrowRight),
                  ),
                  ButtonSegment(
                    value: TunnelKind.remote,
                    label: Text(l10n.tunnelKindRemote),
                    icon: const Icon(PiconsRegular.arrowLeft),
                  ),
                  ButtonSegment(
                    value: TunnelKind.socks,
                    label: Text(l10n.tunnelKindSocks),
                    icon: const Icon(PiconsRegular.globeSimple),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (value) =>
                    setState(() => _kind = value.first),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                switch (_kind) {
                  TunnelKind.local => l10n.tunnelKindLocalHint,
                  TunnelKind.remote => l10n.tunnelKindRemoteHint,
                  TunnelKind.socks => l10n.tunnelKindSocksHint,
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              SectionLabel(l10n.tunnelEditorListen),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _listenHost,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.tunnelEditorListenHost,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: _required(l10n),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _listenPort,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.tunnelEditorPort,
                        border: const OutlineInputBorder(),
                      ),
                      validator: _portValidator(l10n),
                    ),
                  ),
                ],
              ),
              if (!isLoopback) ...[
                const SizedBox(height: Spacing.sm),
                _WarningBanner(text: l10n.tunnelEditorNotLoopback),
              ],

              if (needsTarget) ...[
                SectionLabel(l10n.tunnelEditorTarget),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _targetHost,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l10n.tunnelEditorTargetHost,
                          hintText: l10n.tunnelEditorTargetHostHint,
                          border: const OutlineInputBorder(),
                        ),
                        validator: _required(l10n),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _targetPort,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.tunnelEditorPort,
                          border: const OutlineInputBorder(),
                        ),
                        validator: _portValidator(l10n),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: Spacing.sm),
              SwitchListTile(
                value: _autoStart,
                onChanged: (value) => setState(() => _autoStart = value),
                title: Text(l10n.tunnelEditorAutoStart),
                subtitle: Text(l10n.tunnelEditorAutoStartHint),
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
class _HostDisplay extends StatelessWidget {
  const _HostDisplay({required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.tunnelEditorHost,
        border: const OutlineInputBorder(),
      ),
      child: Text(label ?? '—', style: theme.textTheme.bodyLarge),
    );
  }
}

/// A loopback warning, inline rather than a dialog: the moment the user is
/// typing `0.0.0.0` is the moment they need to see the consequence, not after
/// they have already tapped Save.
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
