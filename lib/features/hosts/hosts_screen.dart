import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'domain/ssh_host.dart';
import 'hosts_controller.dart';
import 'widgets/host_tile.dart';

/// The Hosts destination: the app's front door.
class HostsScreen extends ConsumerWidget {
  const HostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hosts = ref.watch(filteredHostsProvider);
    final query = ref.watch(hostSearchProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.md,
            Spacing.lg,
            Spacing.sm,
          ),
          child: SearchBar(
            hintText: l10n.hostsSearch,
            leading: const Icon(PiconsRegular.magnifyingGlass),
            onChanged: (value) =>
                ref.read(hostSearchProvider.notifier).update(value),
          ),
        ),
        Expanded(
          child: hosts.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(hostsProvider),
              retryLabel: l10n.actionRetry,
            ),
            data: (list) => list.isEmpty
                ? _Empty(hasQuery: query.isNotEmpty)
                : _HostList(hosts: list),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // A search that found nothing is not the same as having no hosts, and
    // offering "import your servers" as the way out of a typo would be noise.
    if (hasQuery) {
      return EmptyView(
        icon: PiconsRegular.magnifyingGlass,
        title: l10n.hostsEmptyTitle,
      );
    }

    return EmptyView(
      icon: PiconsRegular.hardDrives,
      title: l10n.hostsEmptyTitle,
      message: l10n.hostsEmptyBody,
      // The empty state leads with Import, not Add: anyone who wants this app
      // already has their servers written down, and retyping them is the
      // reason an app gets deleted in the first five minutes.
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () => context.pushTo(Routes.importOpenSsh),
            icon: const Icon(PiconsRegular.downloadSimple),
            label: Text(l10n.hostsImport),
          ),
          const SizedBox(height: Spacing.sm),
          TextButton.icon(
            onPressed: () => context.pushTo(Routes.hostNew),
            icon: const Icon(PiconsRegular.plus),
            label: Text(l10n.hostsAdd),
          ),
        ],
      ),
    );
  }
}

class _HostList extends ConsumerWidget {
  const _HostList({required this.hosts});

  final List<SshHost> hosts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContentWidth(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: Spacing.fabClearance),
        itemCount: hosts.length,
        itemBuilder: (context, index) => HostTile(host: hosts[index]),
      ),
    );
  }
}
