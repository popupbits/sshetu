import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Language picker.
///
/// `null` means "follow the device", which is the default and stays the
/// default until the user deliberately pins a language.
class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(
      settingsControllerProvider.select((s) => s.localeCode),
    );
    final l10n = AppLocalizations.of(context);

    String labelFor(String? value) => switch (value) {
      'en' => l10n.languageEnglish,
      'ne' => l10n.languageNepali,
      _ => l10n.languageSystem,
    };

    return ListTile(
      leading: const Icon(PiconsRegular.translate),
      title: Text(l10n.settingsLanguage),
      subtitle: Text(labelFor(code)),
      trailing: PopupMenuButton<String>(
        // '' stands in for null: PopupMenuItem values cannot be null.
        initialValue: code ?? '',
        onSelected: (value) => ref
            .read(settingsControllerProvider.notifier)
            .setLocale(value.isEmpty ? null : value),
        itemBuilder: (context) => [
          PopupMenuItem(value: '', child: Text(l10n.languageSystem)),
          PopupMenuItem(value: 'en', child: Text(labelFor('en'))),
        ],
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}
