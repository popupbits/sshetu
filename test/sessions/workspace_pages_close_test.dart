import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';

/// Closing a workspace tab the way a user does: a page holding unsaved work
/// is asked first, and a "no" keeps it open.
void main() {
  late ProviderContainer container;
  late BuildContext context;

  Future<void> pumpContext(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
  }

  WorkspacePages notifier() => container.read(workspacePagesProvider.notifier);

  WorkspacePage page(String id, {Future<bool> Function(BuildContext)? ask}) =>
      WorkspacePage(
        id: id,
        title: id,
        icon: PiconsRegular.fileText,
        builder: (_) => Text(id),
        confirmClose: ask,
      );

  testWidgets('a page without a check closes at once', (tester) async {
    await pumpContext(tester);
    notifier().open(page('a'));

    await notifier().requestClose(context, 'a');

    expect(container.read(workspacePagesProvider), isEmpty);
  });

  testWidgets('a refused check keeps the tab open', (tester) async {
    await pumpContext(tester);
    var asked = 0;
    notifier().open(
      page(
        'edit',
        ask: (_) async {
          asked++;
          return false;
        },
      ),
    );

    await notifier().requestClose(context, 'edit');

    expect(asked, 1);
    expect(container.read(workspacePagesProvider).single.id, 'edit');
    expect(notifier().selected?.id, 'edit');
  });

  testWidgets('an accepted check closes it', (tester) async {
    await pumpContext(tester);
    notifier().open(page('edit', ask: (_) async => true));

    await notifier().requestClose(context, 'edit');

    expect(container.read(workspacePagesProvider), isEmpty);
  });

  testWidgets('closing a page that is not open does nothing', (tester) async {
    await pumpContext(tester);
    notifier().open(page('a'));

    await notifier().requestClose(context, 'missing');

    expect(container.read(workspacePagesProvider).single.id, 'a');
  });

  test('close itself never asks — it is for code that already decided', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    var asked = false;
    c
        .read(workspacePagesProvider.notifier)
        .open(
          page(
            'edit',
            ask: (_) async {
              asked = true;
              return false;
            },
          ),
        );

    c.read(workspacePagesProvider.notifier).close('edit');

    expect(asked, isFalse);
    expect(c.read(workspacePagesProvider), isEmpty);
  });
}
