import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'domain/snippet_template.dart';
import 'open_snippets.dart';
import 'snippets_controller.dart';
import 'widgets/snippet_tile.dart';

/// The Snippets destination: saved commands, searchable.
///
/// Managing them happens here; *using* one happens from a terminal, through
/// the picker, because that is where there is a session to type it into.
class SnippetsScreen extends ConsumerWidget {
  const SnippetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(snippetSearchProvider);
    final filtered = ref.watch(filteredSnippetsProvider);
    // Whether there is anything to search, not whether the search found
    // anything — the same rule as the host list, for the same reason: the
    // field must not vanish along with the results and take the only way to
    // clear the query with it.
    final hasAny = ref.watch(snippetsProvider).value?.isNotEmpty ?? false;
    final showSearch = hasAny || query.isNotEmpty;

    return Column(
      children: [
        if (showSearch)
          ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.lg,
                Spacing.sm,
              ),
              child: SearchBar(
                key: const Key('snippets.search'),
                hintText: l10n.snippetsSearch,
                leading: const Icon(PiconsRegular.magnifyingGlass),
                onChanged: (value) =>
                    ref.read(snippetSearchProvider.notifier).update(value),
              ),
            ),
          ),
        Expanded(
          child: filtered.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(snippetsProvider),
              retryLabel: l10n.actionRetry,
            ),
            data: (snippets) {
              if (snippets.isNotEmpty) {
                return ContentWidth(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      bottom: Spacing.fabClearance,
                    ),
                    itemCount: snippets.length,
                    itemBuilder: (_, i) => SnippetTile(snippet: snippets[i]),
                  ),
                );
              }
              if (query.trim().isNotEmpty) {
                return EmptyView(
                  icon: PiconsRegular.magnifyingGlass,
                  title: l10n.snippetsNoMatch,
                );
              }
              return EmptyView(
                icon: PiconsRegular.codeBlock,
                title: l10n.snippetsEmptyTitle,
                message: l10n.snippetsEmptyBody(SnippetSyntax.example),
                action: FilledButton.icon(
                  key: const Key('snippets.emptyAdd'),
                  onPressed: () => openSnippetEditor(context, ref),
                  icon: const Icon(PiconsRegular.plus),
                  label: Text(l10n.snippetsAdd),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
