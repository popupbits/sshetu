import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../keys/keys_controller.dart';

/// Which key a new server starts with.
///
/// Most people have one key and use it on everything, so being asked to pick
/// it on every host is a question with the same answer every time. Answering
/// it once here is the difference between adding a server in one field and
/// adding one in four.
class DefaultKeyTile extends ConsumerWidget {
  const DefaultKeyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final identities = ref.watch(identitiesProvider).value ?? const [];
    final chosen = ref.watch(
      settingsControllerProvider.select((s) => s.defaultIdentityId),
    );

    // Nothing to choose between: a picker offering only "No default" is a
    // control that cannot be used, and the Keys screen is where this is
    // fixed.
    if (identities.isEmpty) return const SizedBox.shrink();

    // A key deleted since it was chosen leaves the id behind. Showing "No
    // default" is honest — that is what it now behaves as.
    final valid = identities.any((i) => i.id == chosen) ? chosen : null;

    return ListTile(
      leading: const Icon(PiconsRegular.key),
      title: Text(l10n.settingsDefaultKey),
      // The value in the subtitle and a plain arrow at the end, matching the
      // language picker beside it. A wide control in the trailing slot takes
      // its width from the title, which on a phone squeezed the explanation
      // into a three-line column next to a mostly empty dropdown.
      subtitle: Text(
        valid == null
            ? l10n.settingsDefaultKeyBody
            : identities.firstWhere((i) => i.id == valid).label,
      ),
      trailing: PopupMenuButton<String>(
        // '' stands in for null: PopupMenuItem values cannot be null.
        initialValue: valid ?? '',
        onSelected: (value) => ref
            .read(settingsControllerProvider.notifier)
            .setDefaultIdentity(value.isEmpty ? null : value),
        itemBuilder: (context) => [
          PopupMenuItem(value: '', child: Text(l10n.settingsDefaultKeyNone)),
          for (final identity in identities)
            PopupMenuItem(value: identity.id, child: Text(identity.label)),
        ],
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}
