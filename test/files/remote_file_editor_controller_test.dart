import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/sftp_service.dart';
import 'package:sshetu/features/files/domain/atomic_save.dart';
import 'package:sshetu/features/files/domain/text_document.dart';
import 'package:sshetu/features/files/editor/remote_file_editor_controller.dart';

import 'fake_sftp_service.dart';

void main() {
  late FakeSftpService sftp;
  const path = '/srv/app.ini';

  setUp(() {
    sftp = FakeSftpService();
    sftp.putFile(path, text: '[a]\r\nx=1\r\n');
  });

  Future<RemoteFileEditorController> loaded({int? maxBytes}) async {
    final controller = RemoteFileEditorController(
      sftp: sftp,
      path: path,
      maxBytes: maxBytes ?? kMaxEditableBytes,
    );
    addTearDown(controller.dispose);
    await controller.load();
    return controller;
  }

  group('loading', () {
    test('opens UTF-8 text, CRLF shown as plain lines', () async {
      final c = await loaded();
      expect(c.status, EditorStatus.ready);
      expect(c.text.text, '[a]\nx=1\n');
      expect(c.document!.lineEnding, LineEnding.crlf);
      expect(c.isDirty, isFalse);
      expect(c.name, 'app.ini');
    });

    test('refuses a file over the cap before reading it', () async {
      final c = await loaded(maxBytes: 4);
      expect(c.status, EditorStatus.failed);
      expect(c.loadError, EditorLoadError.tooLarge);
      expect(sftp.fileOps.where((op) => op.startsWith('read')), isEmpty);
    });

    test('refuses binary', () async {
      sftp.putFile(path, bytes: [0x89, 0x50, 0x4E, 0x47, 0, 0, 0]);
      final c = await loaded();
      expect(c.loadError, EditorLoadError.binary);
    });

    test('refuses invalid UTF-8', () async {
      sftp.putFile(path, bytes: [0x63, 0x61, 0x66, 0xE9]);
      final c = await loaded();
      expect(c.loadError, EditorLoadError.notUtf8);
    });

    test('refuses a folder', () async {
      sftp.directories['/srv/dir'] = [];
      final c = RemoteFileEditorController(sftp: sftp, path: '/srv/dir');
      addTearDown(c.dispose);
      await c.load();
      expect(c.loadError, EditorLoadError.notAFile);
    });

    test('reports the server’s reason for anything else', () async {
      sftp.readError = SftpException(
        'Could not open app.ini: permission denied.',
        kind: SftpFailureKind.permissionDenied,
      );
      final c = await loaded();
      expect(c.loadError, EditorLoadError.sftp);
      expect(c.loadMessage, contains('permission denied'));
    });
  });

  group('dirty state', () {
    test('tracks edits, and editing back to the original is clean', () async {
      final c = await loaded();
      var notified = 0;
      c.addListener(() => notified++);

      c.text.text = '[a]\nx=2\n';
      expect(c.isDirty, isTrue);
      expect(notified, greaterThan(0));

      c.text.text = '[a]\nx=1\n';
      expect(c.isDirty, isFalse);
    });

    test('revert restores the loaded text', () async {
      final c = await loaded();
      c.text.text = 'scribble';
      c.revert();
      expect(c.text.text, '[a]\nx=1\n');
      expect(c.isDirty, isFalse);
    });
  });

  group('saving', () {
    test('writes back with the file’s CRLF endings, atomically', () async {
      final c = await loaded();
      c.text.text = '[a]\nx=2\ny=3\n';
      expect(await c.save(), SaveOutcome.saved);
      expect(c.lastSaveMethod, SaveMethod.atomic);
      expect(sftp.textOf(path), '[a]\r\nx=2\r\ny=3\r\n');
      expect(c.isDirty, isFalse);
    });

    test('saving twice does not see its own write as a conflict', () async {
      final c = await loaded();
      c.text.text = 'one\n';
      expect(await c.save(), SaveOutcome.saved);
      c.text.text = 'two\n';
      var asked = false;
      final outcome = await c.save(
        onConflict: () async {
          asked = true;
          return SaveConflictChoice.cancel;
        },
      );
      expect(outcome, SaveOutcome.saved);
      expect(asked, isFalse);
      expect(sftp.textOf(path), 'two\r\n');
    });

    test('a change on the server asks; cancel writes nothing', () async {
      final c = await loaded();
      sftp.changeBehindTheScenes(path, 'theirs\n');
      c.text.text = 'mine\n';

      var asked = 0;
      final outcome = await c.save(
        onConflict: () async {
          asked++;
          return SaveConflictChoice.cancel;
        },
      );
      expect(asked, 1);
      expect(outcome, SaveOutcome.cancelled);
      expect(sftp.textOf(path), 'theirs\n');
      expect(c.isDirty, isTrue);
    });

    test('no resolver means cancel — never a silent overwrite', () async {
      final c = await loaded();
      sftp.changeBehindTheScenes(path, 'theirs\n');
      c.text.text = 'mine\n';
      expect(await c.save(), SaveOutcome.cancelled);
      expect(sftp.textOf(path), 'theirs\n');
    });

    test('overwrite replaces their change with ours', () async {
      final c = await loaded();
      sftp.changeBehindTheScenes(path, 'theirs\n');
      c.text.text = 'mine\n';
      final outcome = await c.save(
        onConflict: () async => SaveConflictChoice.overwrite,
      );
      expect(outcome, SaveOutcome.saved);
      expect(sftp.textOf(path), 'mine\r\n');
    });

    test('reload discards ours and shows theirs', () async {
      final c = await loaded();
      sftp.changeBehindTheScenes(path, 'theirs\n');
      c.text.text = 'mine\n';
      final outcome = await c.save(
        onConflict: () async => SaveConflictChoice.reload,
      );
      expect(outcome, SaveOutcome.reloaded);
      expect(c.text.text, 'theirs\n');
      expect(c.isDirty, isFalse);
      expect(c.status, EditorStatus.ready);
    });

    test('a size change alone is a conflict too', () async {
      final c = await loaded();
      final stat = sftp.fileStats[path]!;
      sftp.putFile(path, text: '[a]\r\nx=10\r\n', modified: stat.modified);
      c.text.text = 'mine\n';
      expect(await c.save(), SaveOutcome.cancelled);
    });

    test('a failed write is reported and the edit kept', () async {
      final c = await loaded();
      sftp
        ..atomicRenameSupported = false
        ..failWriteFor = (_) => true;
      c.text.text = 'mine\n';
      expect(await c.save(), SaveOutcome.failed);
      expect(c.saveError, contains('permission denied'));
      expect(c.isDirty, isTrue);
      expect(c.isSaving, isFalse);
    });

    test('keeps a BOM and LF endings as they were', () async {
      sftp.putFile(path, bytes: [0xEF, 0xBB, 0xBF, ...utf8.encode('a\n')]);
      final c = await loaded();
      c.text.text = 'a\nb\n';
      await c.save();
      expect(sftp.files[path], [0xEF, 0xBB, 0xBF, ...utf8.encode('a\nb\n')]);
    });

    test('stray CRs are shown marked and written back as CRs', () async {
      sftp.putFile(path, text: 'x=1\r\ny=2\rz=3\n');
      final c = await loaded();
      final mark = TextDocument.loneCrMark;
      expect(c.text.text, 'x=1\r\ny=2${mark}z=3\n');
      expect(c.isDirty, isFalse);
      c.text.text = c.text.text.replaceFirst('z=3', 'z=4');
      await c.save();
      expect(sftp.files[path], utf8.encode('x=1\r\ny=2\rz=4\n'));
    });
  });

  test('disposing closes its own SFTP channel', () async {
    final c = RemoteFileEditorController(sftp: sftp, path: path);
    await c.load();
    c.dispose();
    expect(sftp.closeCallCount, 1);
  });
}
