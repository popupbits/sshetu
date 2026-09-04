import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:picons/picons.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({this.embedded = false, super.key});

  /// True when this is a tab in the desktop workspace, which supplies the
  /// title and the way out.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // Embedded, the tab is the title and there are no actions, so a bar
      // here would be an empty strip stealing height from the content.
      appBar: embedded ? null : AppBar(title: Text(l10n.aboutTitle)),
      body: ContentWidth(
        maxWidth: 720,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.xl,
                Spacing.lg,
                Spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: Spacing.xs),
                  // Read from the installed package rather than a constant, so
                  // the version shown can never drift from the one shipped.
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      return Text(
                        info == null
                            ? ''
                            : l10n.aboutVersion(
                                '${info.version}+${info.buildNumber}',
                              ),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text(AppConfig.legalese, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(PiconsRegular.scroll),
              title: Text(l10n.aboutLicenses),
              subtitle: Text(l10n.aboutLicensesSubtitle),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationLegalese: AppConfig.legalese,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
