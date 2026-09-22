import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:picons/picons.dart';

import '../../l10n/app_localizations.dart';
import '../palette/domain/palette_item.dart';
import '../sessions/session_manager.dart';
import 'session_log_actions.dart';
import 'session_log_controller.dart';

/// "Start logging…" or "Stop logging" for the tab in front — the one the
/// palette was opened over.
final sessionLogPaletteItemsProvider =
    Provider.family<List<PaletteItem>, AppLocalizations>((ref, l10n) {
      ref.watch(sessionManagerProvider);
      final logs = ref.watch(sessionLogControllerProvider);
      final active = ref.read(sessionManagerProvider.notifier).active;
      if (active == null) return const [];
      final logging = logs.containsKey(active.id);
      final title = logging
          ? l10n.sessionLogStop
          : l10n.sessionLogStartEllipsis;
      final icon = logging ? PiconsRegular.stopCircle : PiconsRegular.record;
      return [
        PaletteItem(
          id: logging ? 'action:stopLogging' : 'action:startLogging',
          title: title,
          subtitle: active.title,
          category: PaletteCategory.action,
          icon: icon,
          keywords: [l10n.sessionLogKeyword],
          actions: [
            PaletteAction(
              id: 'run',
              label: title,
              icon: icon,
              run: (context, ref) =>
                  unawaited(toggleSessionLog(context, ref, active)),
            ),
          ],
        ),
      ];
    });
