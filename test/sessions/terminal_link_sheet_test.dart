import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sshetu/features/sessions/widgets/terminal_link_sheet.dart';
import 'package:sshetu/l10n/app_localizations.dart';

/// The phone's confirmation before a tapped link leaves the app.
void main() {
  Future<void> pumpSheet(WidgetTester tester, String link) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(body: TerminalLinkSheet(link: link)),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton openButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.text('Open link'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ),
  );

  testWidgets('shows the whole address and offers Open and Copy', (
    tester,
  ) async {
    const link = 'https://example.com/a/very/long/path?with=query#and-fragment';
    await pumpSheet(tester, link);
    expect(find.text('Open this link?'), findsOneWidget);
    expect(find.text(link), findsOneWidget);
    expect(openButton(tester).onPressed, isNotNull);
    expect(find.text('Copy link'), findsOneWidget);
  });

  testWidgets('a refused scheme can be copied but not opened', (tester) async {
    await pumpSheet(tester, 'file:///etc/passwd');
    expect(openButton(tester).onPressed, isNull);
    expect(
      find.text('SSHetu only opens http, https and mailto links.'),
      findsOneWidget,
    );
  });

  testWidgets('Copy puts the link on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openTerminalLink(
                context,
                'mailto:ops@example.com',
                confirm: true,
              ),
              child: const Text('tap link'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('tap link'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalLinkSheet), findsOneWidget);

    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, 'mailto:ops@example.com');
    expect(find.byType(TerminalLinkSheet), findsNothing);
    expect(find.text('Link copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('without confirmation a refused link is refused aloud', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openTerminalLink(
                context,
                'x-custom://run?cmd=calc',
                confirm: false,
              ),
              child: const Text('ctrl-click link'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ctrl-click link'));
    await tester.pumpAndSettle();
    expect(
      find.text('SSHetu only opens http, https and mailto links.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });
}
