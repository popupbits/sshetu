import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../hosts/domain/ssh_host.dart';
import '../../hosts/hosts_controller.dart';
import '../connect.dart';

/// The desktop workspace's left column: every saved host, one click from a
/// session.
///
/// Desktop only, and it is not a duplicate of the Hosts screen. The question
/// it answers is different: Hosts is where you *manage* servers, this is where
/// you *reach* them without leaving the terminal you are already in. On a phone
/// there is no room for both at once, which is why the phone keeps the two as
/// separate destinations instead.
class HostSidebar extends ConsumerStatefulWidget {
  const HostSidebar({super.key});

  @override
  ConsumerState<HostSidebar> createState() => _HostSidebarState();
}

class _HostSidebarState extends ConsumerState<HostSidebar> {
  final _controller = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hosts = ref.watch(hostsProvider).value ?? const <SshHost>[];
    final matching = hosts.where((h) => h.matches(_query)).toList();

    return Container(
      width: 260,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: TextField(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.hostsSearch,
                prefixIcon: const Icon(PiconsRegular.magnifyingGlass, size: 16),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.xs),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.sm,
                ),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: matching.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Text(
                        hosts.isEmpty
                            ? l10n.hostsEmptyTitle
                            : l10n.hostsNoMatches,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: matching.length,
                    itemBuilder: (context, index) {
                      final host = matching[index];
                      return _SidebarRow(host: host);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SidebarRow extends ConsumerWidget {
  const _SidebarRow({required this.host});

  final SshHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: () => connectToHost(context, ref, host),
      child: Container(
        height: Chrome.row + Spacing.md,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        child: Row(
          children: [
            Icon(
              PiconsRegular.hardDrive,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    host.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    host.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
