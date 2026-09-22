import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/domain/host_tmux_mode.dart';

void main() {
  group('resolve: the host choice over the app-wide setting', () {
    final cases = {
      (HostTmuxMode.followDefault, true): true,
      (HostTmuxMode.followDefault, false): false,
      (HostTmuxMode.always, true): true,
      (HostTmuxMode.always, false): true,
      (HostTmuxMode.never, true): false,
      (HostTmuxMode.never, false): false,
    };
    for (final MapEntry(key: (mode, global), value: expected)
        in cases.entries) {
      test('${mode.name} with the setting ${global ? 'on' : 'off'} '
          '→ ${expected ? 'tmux' : 'plain'}', () {
        expect(mode.resolve(globalDefault: global), expected);
      });
    }
  });

  group('storage', () {
    test('default is NULL; the others are their names', () {
      expect(HostTmuxMode.followDefault.storageValue, isNull);
      expect(HostTmuxMode.always.storageValue, 'always');
      expect(HostTmuxMode.never.storageValue, 'never');
    });

    test('export names default explicitly', () {
      expect(HostTmuxMode.followDefault.exportValue, 'default');
      expect(HostTmuxMode.always.exportValue, 'always');
      expect(HostTmuxMode.never.exportValue, 'never');
    });

    test('reads back every value it writes', () {
      for (final mode in HostTmuxMode.values) {
        expect(HostTmuxMode.fromStorage(mode.storageValue), mode);
        expect(HostTmuxMode.fromStorage(mode.exportValue), mode);
      }
    });

    test('anything else follows the setting', () {
      for (final value in [null, '', 'default', 'ALWAYS', 'sometimes']) {
        expect(HostTmuxMode.fromStorage(value), HostTmuxMode.followDefault);
      }
    });
  });
}
