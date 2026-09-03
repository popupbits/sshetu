import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'router/router.dart';
import 'settings/settings_controller.dart';
import 'theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'update/update_listener.dart';

/// Root of the widget tree.
class SshNavigatorApp extends ConsumerWidget {
  const SshNavigatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SSH Navigator',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,

      theme: AppTheme.light(settings.accent),
      darkTheme: AppTheme.dark(settings.accent),
      themeMode: settings.themeMode.themeMode,

      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      // material_ui exports its own GlobalMaterialLocalizations covering
      // Flutter, Material and Cupertino strings, so this app does not depend
      // on flutter_localizations directly.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],

      builder: (context, child) {
        // Bridges packages that still import package:flutter/material.dart —
        // google_fonts, go_router's MaterialPage, picons — so their widgets
        // can resolve a legacy Theme and MaterialLocalizations inside this
        // material_ui tree. Without it they throw at runtime.
        // Deprecated upstream on purpose: it is a migration utility, and
        // it stays necessary for exactly as long as our dependencies keep
        // importing frozen Material. Drop it once they no longer do.
        // ignore: deprecated_member_use
        final bridged = MaterialUiCompatibilityBridge(child: child!);
        final wrapped = UpdateListener(child: bridged);
        // The user's text-size preference multiplies the platform scale
        // rather than replacing it, so device accessibility settings still
        // apply on top.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: settings.textScale,
              maxScaleFactor: settings.textScale * 1.6,
            ),
          ),
          child: wrapped,
        );
      },
    );
  }
}

/// Root messenger, so a snackbar can be shown from outside any screen —
/// the in-app-update flow and bootstrap diagnostics both need this.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
