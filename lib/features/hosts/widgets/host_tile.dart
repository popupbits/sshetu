import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../sessions/open_screens.dart';

import '../../../core/ssh/ssh_target.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/context_menu.dart';
import '../../../core/ui/feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../sessions/connect.dart';
import '../domain/ssh_host.dart';
import '../hosts_controller.dart';
import 'host_notes_dialog.dart';

/// One saved server, as a row.
///
/// Carries four things, in the order they are wanted: what it is called, where
/// it is, how it authenticates, and when it was last used. Anything more and a
/// list of thirty servers stops being scannable, which is the only thing this
/// screen has to be good at.
class HostTile extends ConsumerWidget {
  const HostTile({required this.host, super.key});

  final SshHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContextMenuRegion(
      title: host.label,
      // Built on demand so it reflects the host as it is when opened, not as
      // it was when the row was laid out.
      actions: () => [
        MenuAction(
          label: l10n.hostsConnect,
          icon: PiconsRegular.terminalWindow,
          onSelected: () => connectToHost(context, ref, host),
        ),
        MenuAction(
          label: l10n.hostsEdit,
          icon: PiconsRegular.pencilSimple,
          onSelected: () => openHostEditor(context, ref, hostId: host.id),
        ),
        if (host.hasNotes)
          MenuAction(
            label: l10n.hostsShowNotes,
            icon: PiconsRegular.note,
            onSelected: () => showHostNotes(context, ref, host),
          ),
        MenuAction(
          label: l10n.hostsDelete,
          icon: PiconsRegular.trash,
          isDestructive: true,
          onSelected: () async {
            final confirmed = await context.confirm(
              title: l10n.hostsDeleteConfirm,
              message: l10n.hostsDeleteBody,
              confirmLabel: l10n.hostsDelete,
              isDestructive: true,
            );
            if (confirmed) {
              try {
                await ref.read(hostsControllerProvider).delete(host.id);
              } on Object {
                // The host is gone either way — the row was tombstoned before
                // the vault was touched. What failed is erasing the saved
                // password, and someone deleting a host deserves to know that
                // it may still be in their keychain.
                if (context.mounted) {
                  context.toast(l10n.secretNotErased, isError: true);
                }
              }
            }
          },
        ),
      ],
      child: ListTile(
        onTap: () => connectToHost(context, ref, host),
        // Denser than Material's default: this is a list to scan, and thirty
        // servers at comfortable density is a lot of scrolling for no gain.
        visualDensity: VisualDensity.compact,
        minVerticalPadding: Spacing.sm,
        leading: _Monogram(host: host),
        title: Row(
          children: [
            Flexible(
              flex: 3,
              child: Text(
                host.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (host.jumpHostId != null) ...[
              const SizedBox(width: Spacing.sm),
              Tooltip(
                message: l10n.hostEditorJump,
                child: Icon(
                  PiconsRegular.arrowsLeftRight,
                  size: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (host.allowLegacyAlgorithms) ...[
              const SizedBox(width: Spacing.xs),
              Tooltip(
                // Not decoration: a host connecting on weakened algorithms
                // should say so wherever it appears, not only in its editor.
                message: l10n.hostEditorLegacy,
                child: Icon(
                  PiconsRegular.shieldWarning,
                  size: 13,
                  color: scheme.error,
                ),
              ),
            ],
            if (host.hasNotes) ...[
              const SizedBox(width: Spacing.xs),
              // A marker, not a button: it is far too small to tap. Hover
              // shows the note on a desktop; the row's menu opens it anywhere.
              Tooltip(
                message: _notePreview(host.notes!),
                child: Icon(
                  PiconsRegular.note,
                  size: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (host.tags.isNotEmpty) ...[
              const SizedBox(width: Spacing.sm),
              // Flex 2 against the name's 3: tags may shrink and ellipsise,
              // but never take the row from the name, which is what the eye
              // is scanning for.
              Flexible(flex: 2, child: _TagPills(tags: host.tags)),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            // Auth and age move onto the second line, next to the address they
            // describe. As a trailing cluster they cost 120px of the row, which
            // in a 320px side panel is most of the name — every host came out as
            // `192.168....`, and the octets are the only part that identifies it.
            Icon(
              // `password` draws a row of asterisks, which at this size is a
              // smear rather than a symbol. A closed padlock reads instantly
              // and pairs naturally with the key.
              host.authMethod == SshAuthMethod.password
                  ? PiconsRegular.lockSimple
                  : PiconsRegular.key,
              size: 12,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.xs),
            Flexible(
              child: Text(
                host.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (host.lastConnectedAt != null) ...[
              Text(
                ' · ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                _lastUsed(context, host.lastConnectedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        // Only the menu is trailing now, so the name has the row.
        trailing: _HostMenu(host: host),
      ),
    );
  }

  /// The first few lines of a note, for a tooltip.
  static String _notePreview(String notes) {
    final text = notes.trim();
    const limit = 280;
    return text.length <= limit ? text : '${text.substring(0, limit)}…';
  }

  /// A short relative age — `2h`, `3d`, `—`.
  ///
  /// Short on purpose: this column exists so the eye can find "the one I used
  /// this morning" while scanning, and a full timestamp in every row would be
  /// noise competing with the address.
  static String _lastUsed(BuildContext context, DateTime? at) {
    final l10n = AppLocalizations.of(context);
    if (at == null) return '—';
    final elapsed = DateTime.now().toUtc().difference(at);
    if (elapsed.inMinutes < 1) return l10n.timeNow;
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h';
    if (elapsed.inDays < 365) return '${elapsed.inDays}d';
    return '${(elapsed.inDays / 365).floor()}y';
  }
}

/// The row's avatar.
///
/// Tinted from the label so the same host is the same colour every time. Hosts
/// are frequently named as bare addresses, and a column of near-identical
/// numbers has nothing for the eye to catch — this gives each row a stable
/// shape and colour to recognise before any text is read.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.host});

  final SshHost host;

  /// Fixed hues rather than a full spectrum: picked to stay distinguishable
  /// from each other and legible on both light and dark surfaces.
  static const _hues = <double>[8, 40, 140, 190, 220, 265, 320];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    // A stable hash of the label, so a host keeps its colour across restarts
    // and across devices — `hashCode` on a String is not guaranteed stable
    // between runs, so it cannot be used here.
    var hash = 0;
    for (final unit in host.label.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final hue = _hues[hash % _hues.length];
    // Saturation high enough that the hues are actually distinguishable from
    // each other: the first attempt used 0.35/0.62 over a 22% wash, and every
    // monogram in a real list came out the same muted grey — a colour code
    // that codes nothing. Lightness is the part that adapts to the theme;
    // saturation stays up in both.
    final color = HSLColor.fromAHSL(
      1,
      hue,
      dark ? 0.62 : 0.70,
      dark ? 0.68 : 0.42,
    ).toColor();

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        host.monogram,
        maxLines: 1,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          // Addresses monogram to digits; tabular figures keep them from
          // jittering between rows.
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// At most two tags as small pills, then `+N`.
///
/// Two, not all: a row carrying five tags is a row whose name has been
/// crowded out, and the filter row above the list is where every tag lives.
class _TagPills extends StatelessWidget {
  const _TagPills({required this.tags});

  final List<String> tags;

  static const _shown = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSecondaryContainer,
    );
    final extra = tags.length - _shown;

    Widget pill(String text) => Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs + Spacing.xxs,
        vertical: Spacing.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, tag) in tags.take(_shown).indexed) ...[
          if (i > 0) const SizedBox(width: Spacing.xs),
          Flexible(child: pill(tag)),
        ],
        if (extra > 0) ...[
          const SizedBox(width: Spacing.xs),
          Text(
            '+$extra',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _HostMenu extends ConsumerWidget {
  const _HostMenu({required this.host});

  final SshHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(PiconsRegular.pencilSimple),
          onPressed: () => openHostEditor(context, ref, hostId: host.id),
          child: Text(l10n.hostsEdit),
        ),
        if (host.hasNotes)
          MenuItemButton(
            leadingIcon: const Icon(PiconsRegular.note),
            onPressed: () => showHostNotes(context, ref, host),
            child: Text(l10n.hostsShowNotes),
          ),
        MenuItemButton(
          leadingIcon: Icon(PiconsRegular.trash, color: scheme.error),
          onPressed: () async {
            final confirmed = await context.confirm(
              title: l10n.hostsDeleteConfirm,
              message: l10n.hostsDeleteBody,
              confirmLabel: l10n.hostsDelete,
              isDestructive: true,
            );
            if (confirmed) {
              try {
                await ref.read(hostsControllerProvider).delete(host.id);
              } on Object {
                // The host is gone either way — the row was tombstoned before
                // the vault was touched. What failed is erasing the saved
                // password, and someone deleting a host deserves to know that
                // it may still be in their keychain.
                if (context.mounted) {
                  context.toast(l10n.secretNotErased, isError: true);
                }
              }
            }
          },
          child: Text(l10n.hostsDelete),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: const Icon(PiconsRegular.dotsThreeVertical, size: 18),
        visualDensity: VisualDensity.compact,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
