import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../sessions/open_screens.dart';

import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'domain/host_sections.dart';
import 'hosts_controller.dart';
import 'widgets/group_actions.dart';
import 'widgets/host_group_header.dart';
import 'widgets/host_tile.dart';
import 'widgets/reachability_scope.dart';
import 'widgets/tag_filter_bar.dart';

/// The Hosts destination: the app's front door.
class HostsScreen extends ConsumerWidget {
  const HostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sections = ref.watch(hostSectionsProvider);
    final query = ref.watch(hostSearchProvider);
    final filtering =
        query.isNotEmpty || ref.watch(hostTagFilterProvider).isNotEmpty;
    final hasGroups = ref.watch(hostGroupsProvider).value?.isNotEmpty ?? false;

    // Whether there is anything to search — not whether the *filtered* list
    // has anything in it. A field for narrowing an empty list can do nothing
    // but sit there, and on an otherwise empty screen it is the heaviest
    // thing on it, drawing the eye away from the two buttons that are the
    // entire point. It stays as soon as one host exists, and stays while a
    // query is typed even when that query matches nothing — otherwise the
    // field would vanish along with the results and take with it the only
    // way to clear it.
    final hasAnyHost = ref.watch(hostsProvider).value?.isNotEmpty ?? false;
    final showSearch = hasAnyHost || query.isNotEmpty;

    return Column(
      children: [
        if (showSearch)
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
              // Beside the search rather than in the app bar: it is about
              // this list, and the app bar is shared by every layout.
              trailing: [
                IconButton(
                  tooltip: l10n.hostsNewGroup,
                  icon: const Icon(PiconsRegular.folderPlus),
                  onPressed: () => createGroupFlow(context, ref),
                ),
              ],
              onChanged: (value) =>
                  ref.read(hostSearchProvider.notifier).update(value),
            ),
          ),
        if (showSearch) const TagFilterBar(),
        Expanded(
          child: sections.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(hostsProvider),
              retryLabel: l10n.actionRetry,
            ),
            data: (list) => list.every((s) => s.hosts.isEmpty)
                ? _Empty(hasQuery: filtering)
                : ReachabilityScope(
                    child: _HostList(sections: list, showHeaders: hasGroups),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends ConsumerWidget {
  const _Empty({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onPressed: () => openImport(context, ref),
            icon: const Icon(PiconsRegular.downloadSimple),
            label: Text(l10n.hostsImport),
          ),
          const SizedBox(height: Spacing.sm),
          TextButton.icon(
            onPressed: () => openHostEditor(context, ref),
            icon: const Icon(PiconsRegular.plus),
            label: Text(l10n.hostsAdd),
          ),
        ],
      ),
    );
  }
}

/// The hosts, in collapsible group sections when there are groups.
///
/// Flattened into one lazily-built list of rows — headers and hosts alike —
/// rather than a column of per-group lists, so two hundred servers still
/// build only the rows on screen.
class _HostList extends ConsumerWidget {
  const _HostList({required this.sections, required this.showHeaders});

  final List<HostSection> sections;

  /// False when there are no groups: the list then looks exactly as it did
  /// before groups existed, with no lone "Ungrouped" header over everything.
  final bool showHeaders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(collapsedHostGroupsProvider);
    final rows = <Widget Function(BuildContext)>[];

    for (final section in sections) {
      final isCollapsed = showHeaders && collapsed.contains(section.key);
      if (showHeaders) {
        rows.add(
          (_) => HostGroupHeader(
            key: ValueKey('group-${section.key}'),
            section: section,
            collapsed: isCollapsed,
          ),
        );
      }
      if (isCollapsed) continue;
      if (showHeaders && section.hosts.isEmpty) {
        rows.add((context) => const _EmptyGroupHint());
      }
      for (final host in section.hosts) {
        rows.add((_) => HostTile(key: ValueKey(host.id), host: host));
      }
    }

    return ContentWidth(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: Spacing.fabClearance),
        itemCount: rows.length,
        itemBuilder: (context, index) => rows[index](context),
      ),
    );
  }
}

/// What an open, empty group says, so it does not look like a broken header.
class _EmptyGroupHint extends StatelessWidget {
  const _EmptyGroupHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xxxl,
        0,
        Spacing.lg,
        Spacing.md,
      ),
      child: Text(
        AppLocalizations.of(context).hostGroupEmpty,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
