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

    // Each language is named in itself — "English", "नेपाली" — whatever the
    // app is currently showing, so someone who switched by mistake can still
    // find their way back. The name comes from that language's own .arb.
    String labelFor(String? value) => switch (value) {
      'en' => lookupAppLocalizations(const Locale('en')).languageEnglish,
      'ne' => lookupAppLocalizations(const Locale('ne')).languageNepali,
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
          PopupMenuItem(value: 'ne', child: Text(labelFor('ne'))),
        ],
        icon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}
