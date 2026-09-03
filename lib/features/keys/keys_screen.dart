import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/feedback.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'keys_controller.dart';
import 'widgets/generate_key_sheet.dart';

/// The Keys destination.
class KeysScreen extends ConsumerWidget {
  const KeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final identities = ref.watch(identitiesProvider);

    return identities.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: '$error',
        onRetry: () => ref.invalidate(identitiesProvider),
        retryLabel: l10n.actionRetry,
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyView(
            icon: PiconsRegular.key,
            title: l10n.keysEmptyTitle,
            message: l10n.keysEmptyBody,
            // Generate leads, import follows. On a phone there is no ~/.ssh
            // to import from, so the button that always works goes first.
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: () => showGenerateKeySheet(context),
                  icon: const Icon(PiconsRegular.key),
                  label: Text(l10n.keysGenerate),
                ),
                const SizedBox(height: Spacing.sm),
                TextButton.icon(
                  onPressed: () => context.pushTo(Routes.importFocused('keys')),
                  icon: const Icon(PiconsRegular.downloadSimple),
                  label: Text(l10n.keysImport),
                ),
              ],
            ),
          );
        }

        return ContentWidth(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: Spacing.fabClearance),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final identity = list[index];
              final theme = Theme.of(context);

              return ListTile(
                leading: const Icon(PiconsRegular.key),
                title: Text(identity.label),
                subtitle: Text(
                  [
                    identity.keyType,
                    if (identity.hasPassphrase) l10n.keysEncrypted,
                    if (identity.fingerprint != null) identity.fingerprint!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: MenuAnchor(
                  menuChildren: [
                    if (identity.publicKey != null)
                      MenuItemButton(
                        leadingIcon: const Icon(PiconsRegular.copy),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: identity.publicKey!),
                          );
                          if (context.mounted) context.toast(l10n.keysCopied);
                        },
                        child: Text(l10n.keysCopyPublic),
                      ),
                    MenuItemButton(
                      leadingIcon: Icon(
                        PiconsRegular.trash,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () async {
                        final confirmed = await context.confirm(
                          title: l10n.keysDeleteConfirm,
                          // Said bluntly: this is genuinely unrecoverable, and
                          // a key the user has no other copy of is a server
                          // they can no longer reach.
                          message: l10n.keysDeleteBody,
                          confirmLabel: l10n.keysDelete,
                          isDestructive: true,
                        );
                        if (confirmed) {
                          await ref
                              .read(identitiesControllerProvider)
                              .delete(identity.id);
                        }
                      },
                      child: Text(l10n.keysDelete),
                    ),
                  ],
                  builder: (context, controller, _) => IconButton(
                    icon: const Icon(PiconsRegular.dotsThreeVertical),
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
