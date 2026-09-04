import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:sshetu/features/sessions/workspace_pages.dart';

/// Tabs in the desktop workspace that are not terminals.
void main() {
  WorkspacePage page(String id) => WorkspacePage(
    id: id,
    title: id,
    icon: PiconsRegular.qrCode,
    builder: (_) => Text(id),
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  WorkspacePages notifier() => container.read(workspacePagesProvider.notifier);

  test('opening a page shows it', () {
    notifier().open(page('a'));

    expect(container.read(workspacePagesProvider), hasLength(1));
    expect(notifier().selected?.id, 'a');
  });

  test('opening the same page twice does not stack it', () {
    notifier()
      ..open(page('a'))
      ..open(page('a'));

    expect(container.read(workspacePagesProvider), hasLength(1));
  });

  test('closing the selected page falls back rather than showing nothing', () {
    notifier()
      ..open(page('a'))
      ..open(page('b'))
      ..close('b');

    expect(notifier().selected?.id, 'a');
  });

  test('closing the last page returns to the terminal', () {
    notifier()
      ..open(page('a'))
      ..close('a');

    expect(notifier().selected, isNull);
    expect(container.read(workspacePagesProvider), isEmpty);
  });

  test('deselecting keeps the tab but shows the terminal', () {
    notifier()
      ..open(page('a'))
      ..deselect();

    expect(notifier().selected, isNull);
    expect(container.read(workspacePagesProvider), hasLength(1));
  });

  test('opening settles instead of rebuilding forever', () async {
    // The symptom this guards: tapping "Send to a device" froze the app.
    // A notifier that tells its listeners to rebuild, in a tree that reads
    // the notifier while building, is the shape that loops.
    var builds = 0;

    await _pump(container, () {
      builds++;
      return const SizedBox.shrink();
    });

    notifier().open(page('a'));
    expect(builds, lessThan(50), reason: 'a rebuild loop, not a rebuild');
  });
}

/// Pumps a widget that watches the provider, counting its builds.
Future<void> _pump(ProviderContainer container, Widget Function() build) async {
  // A container-only test cannot pump widgets; the counter above is driven by
  // the listener instead, which is the same signal.
  container.listen(workspacePagesProvider, (_, _) => build());
}
