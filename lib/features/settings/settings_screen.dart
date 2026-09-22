import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import 'settings_scroll_request.dart';
import 'tiles.dart';

/// The Settings destination.
///
/// Body content only — the shell owns the Scaffold and AppBar. Rows come from
/// [settingsSections] so features can add their own without editing this file.
///
/// Answers a [SettingsScrollRequest] by bringing that section into view, which
/// is what lets the command palette open Settings at "Terminal" rather than at
/// the top. Every section is built up front (there are a handful), so the one
/// asked for always has a context to scroll to.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _sectionKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    // A request made before this screen existed — the palette navigates here
    // and asks in the same breath.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(settingsScrollRequestProvider);
      if (pending != null) _reveal(pending);
    });
  }

  void _reveal(SettingsScrollRequest request) {
    final target = _sectionKeys[request.sectionTitle]?.currentContext;
    if (target == null) return;
    ref.read(settingsScrollRequestProvider.notifier).clear();
    Scrollable.ensureVisible(target, duration: Motion.normal);
  }

  @override
  Widget build(BuildContext context) {
    final sections = settingsSections(context, ref);
    ref.listen(settingsScrollRequestProvider, (_, request) {
      if (request != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reveal(request);
        });
      }
    });

    return ContentWidth(
      maxWidth: 720,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Spacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in sections)
              Column(
                key: _sectionKeys.putIfAbsent(section.title, GlobalKey.new),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [SectionLabel(section.title), ...section.tiles],
              ),
          ],
        ),
      ),
    );
  }
}
