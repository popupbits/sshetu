import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import 'tiles.dart';

/// The Settings destination.
///
/// Body content only — the shell owns the Scaffold and AppBar. Rows come from
/// [settingsSections] so features can add their own without editing this file.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = settingsSections(context, ref);

    return ContentWidth(
      maxWidth: 720,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: Spacing.xxl),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [SectionLabel(section.title), ...section.tiles],
          );
        },
      ),
    );
  }
}
