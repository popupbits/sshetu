import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/providers.dart';
import '../../core/ssh/host_key.dart';
import '../../core/theme/terminal_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/feedback.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/known_hosts_import_dialog.dart';

/// Every server identity this device has accepted, and the only way to revoke
/// one.
///
/// This screen is not optional decoration. The host key verifier refuses a
/// *changed* key outright and never offers a "trust anyway" button, which is
/// the single guarantee that makes host key checking worth having — and it
/// leaves exactly one legitimate way forward when a server really was rebuilt:
/// the user deliberately forgetting the old pin. Without this screen that exit
/// does not exist, and the pressure to add a "trust anyway" button somewhere
/// worse becomes irresistible.
class KnownHostsScreen extends ConsumerWidget {
  const KnownHostsScreen({this.embedded = false, super.key});

  /// True when this is a tab in the desktop workspace, which supplies the
  /// title and the way out.
  final bool embedded;

  static const importKey = ValueKey('known-hosts-import');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final store = ref.watch(knownHostsProvider);
    final importButton = TextButton.icon(
      key: embedded ? importKey : null,
      onPressed: () => unawaited(importKnownHosts(context, ref)),
      icon: const Icon(PiconsRegular.fileArrowDown, size: 18),
      label: Text(l10n.knownHostsImport),
    );

    final body = store.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(knownHostsProvider),
        retryLabel: l10n.actionRetry,
      ),
      data: (hosts) {
        final keys = hosts.all();
        if (keys.isEmpty) {
          return EmptyView(
            icon: PiconsRegular.shieldCheck,
            title: l10n.knownHostsEmptyTitle,
            message: l10n.knownHostsEmptyBody,
          );
        }

        return ContentWidth(
          child: ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) => _KnownHostTile(entry: keys[index]),
          ),
        );
      },
    );

    return Scaffold(
      // Embedded, the tab is the title, so the import action sits in a slim
      // row of its own rather than an app bar that would be mostly empty.
      // In an app bar the action is an icon: a phone-width bar has no room
      // for the title and a labelled button both.
      appBar: embedded
          ? null
          : AppBar(
              title: Text(l10n.knownHostsTitle),
              actions: [
                IconButton(
                  key: importKey,
                  tooltip: l10n.knownHostsImport,
                  onPressed: () => unawaited(importKnownHosts(context, ref)),
                  icon: const Icon(PiconsRegular.fileArrowDown),
                ),
              ],
            ),
      body: embedded
          ? Column(
              children: [
                ContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xs,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: importButton,
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}

class _KnownHostTile extends ConsumerWidget {
  const _KnownHostTile({required this.entry});

  final KnownHostKey entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // A hashed entry's name is a salted hash — showing it would be noise
    // that looks like a hostname. It is labelled for what it is instead.
    final address = entry.isHashed
        ? l10n.knownHostsHashedTitle
        : entry.port == 22
        ? entry.hostname
        : '${entry.hostname}:${entry.port}';

    return ListTile(
      isThreeLine: true,
      leading: Icon(PiconsRegular.shieldCheck, color: scheme.primary),
      title: Text(address),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Spacing.xxs),
          // Monospace and selectable: the whole point of a fingerprint is
          // comparing it, character by character, against what the server's
          // operator published. A proportional font makes that harder than it
          // needs to be, and text you cannot select cannot be pasted into
          // whatever you are comparing it with.
          SelectableText(
            entry.fingerprint,
            style: Mono.apply(theme.textTheme.bodySmall),
          ),
          Text(
            '${entry.keyType} · ${l10n.knownHostsTrustedOn(_date(entry.trustedAt))}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: MenuAnchor(
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(PiconsRegular.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: entry.fingerprint));
              if (context.mounted) context.toast(l10n.knownHostsCopied);
            },
            child: Text(l10n.keysCopyPublic),
          ),
          MenuItemButton(
            leadingIcon: Icon(PiconsRegular.trash, color: scheme.error),
            onPressed: () async {
              final confirmed = await context.confirm(
                title: l10n.knownHostsForgetConfirm,
                // Says plainly what forgetting means and when it is not the
                // right answer. This is the one action in the app that can
                // walk a user into accepting a man-in-the-middle, so it does
                // not get a breezy confirmation.
                message: l10n.knownHostsForgetBody,
                confirmLabel: l10n.knownHostsForget,
                isDestructive: true,
              );
              if (!confirmed) return;
              final store = await ref.read(knownHostsProvider.future);
              await store.forget(entry.hostname, entry.port);
              ref.invalidate(knownHostsProvider);
            },
            child: Text(l10n.knownHostsForget),
          ),
        ],
        builder: (context, controller, _) => IconButton(
          icon: const Icon(PiconsRegular.dotsThreeVertical),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }

  static String _date(DateTime at) {
    final local = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
