import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';
import 'package:sshetu/features/import/putty/putty_import.dart';
import 'package:sshetu/features/import/putty/putty_reg.dart';
import 'package:sshetu/features/import/putty/putty_sessions.dart';
import 'package:sshetu/features/tunnels/domain/tunnel.dart';

import 'putty_fixture.dart';

void main() {
  group('decoding the bytes', () {
    test('UTF-16LE with a BOM, as reg export writes it', () {
      final text = decodeRegBytes(utf16leWithBom(kPuttyReg));
      expect(text, startsWith('Windows Registry Editor Version 5.00'));
      expect(text, contains('bastion.example.com'));
    });

    test('UTF-16LE without a BOM', () {
      final bytes = utf16leWithBom(kPuttyReg).sublist(2);
      expect(decodeRegBytes(bytes), startsWith('Windows Registry'));
    });

    test('UTF-8, with or without a BOM', () {
      final plain = Uint8List.fromList(utf8.encode(kPuttyReg));
      expect(decodeRegBytes(plain), startsWith('Windows Registry'));
      final bom = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...plain]);
      expect(decodeRegBytes(bom), startsWith('Windows Registry'));
    });
  });

  group('parsing .reg text', () {
    final keys = parseRegText(kPuttyReg);

    test('reads every key', () {
      expect(keys.map((k) => k.path.split(r'\').last), [
        'Sessions',
        'Default%20Settings',
        'My%20Server',
        'bastion',
        'router%20telnet',
        'Caf%C3%A9%20box',
        'empty',
      ]);
    });

    test('strings, with escapes', () {
      final server = keys[2];
      expect(server.string('HostName'), 'myserver.example.com');
      expect(server.string('PublicKeyFile'), r'C:\Users\me\keys\work.ppk');
      expect(server.string('WinTitle'), 'say "hi"');
    });

    test('dwords, in hex', () {
      expect(keys[2].dword('PortNumber'), 0x16);
      expect(keys[3].dword('PortNumber'), 2222);
    });

    test('a hex value continued over lines is skipped whole', () {
      expect(keys[2].values.containsKey('Colour0'), isFalse);
      // …and the value after it is still read.
      expect(keys[2].string('TerminalType'), 'xterm');
    });

    test('a deleted key is ignored', () {
      expect(parseRegText('[-HKEY_CURRENT_USER\\x]\n"a"="b"\n'), isEmpty);
    });
  });

  test('percent-encoded session names', () {
    expect(decodePuttySessionName('My%20Server'), 'My Server');
    expect(decodePuttySessionName('Caf%C3%A9%20box'), 'Café box');
    expect(decodePuttySessionName('100%'), '100%');
    expect(decodePuttySessionName('a%2Fb%zz'), 'a/b%zz');
  });

  group('sessions', () {
    final sessions = puttySessionsFrom(parseRegText(kPuttyReg));
    PuttySession named(String name) =>
        sessions.firstWhere((s) => s.name == name);

    test('are every session but the empty default', () {
      expect(sessions.map((s) => s.name), [
        'My Server',
        'bastion',
        'router telnet',
        'Café box',
        'empty',
      ]);
    });

    test('carry host, port and user', () {
      final server = named('My Server');
      expect(server.hostname, 'myserver.example.com');
      expect(server.port, 22);
      expect(server.username, 'admin');
      expect(server.importable, isTrue);
    });

    test('user@host in the host box is split', () {
      final bastionSession = named('bastion');
      expect(bastionSession.hostname, 'bastion.example.com');
      expect(bastionSession.username, 'jump');
      expect(bastionSession.port, 2222);
    });

    test('a non-SSH session is skipped, and says why', () {
      expect(named('router telnet').skip, PuttySkip.notSsh);
      expect(named('router telnet').protocol, 'telnet');
    });

    test('no host name is skipped', () {
      expect(named('empty').skip, PuttySkip.noHostName);
    });

    test('a .ppk key and a proxy are reported', () {
      final server = named('My Server');
      expect(server.keyFile, endsWith('work.ppk'));
      expect(server.proxy!.method, 'SOCKS5');
      expect(server.proxy!.description, 'SOCKS5 proxy.corp:1080');
      expect(named('bastion').proxy, isNull);
    });

    test('port forwardings', () {
      final server = named('My Server');
      expect(server.forwards.map((f) => f.raw), [
        'L8080=localhost:80',
        'R2222=127.0.0.1:22',
        'D1080',
        'L127.0.0.1:5433=[::1]:5432',
      ]);
      expect(server.invalidForwards, ['Xbogus']);
      final local = server.forwards[0];
      expect(local.kind, TunnelKind.local);
      expect(local.listenPort, 8080);
      expect(local.listenHost, isNull);
      expect(local.targetHost, 'localhost');
      expect(local.targetPort, 80);
      expect(server.forwards[1].kind, TunnelKind.remote);
      expect(server.forwards[2].kind, TunnelKind.socks);
      expect(server.forwards[2].targetHost, isNull);
      expect(server.forwards[3].listenHost, '127.0.0.1');
      expect(server.forwards[3].targetHost, '::1');
    });
  });

  group('parsePuttyForwardings', () {
    test('address-family prefixes and a D entry with an =', () {
      final (forwards, invalid) = parsePuttyForwardings(
        '4L10=a:1,6R20=b:2,D30=',
      );
      expect(forwards.map((f) => f.listenPort), [10, 20, 30]);
      expect(invalid, isEmpty);
    });

    test('rejects what it cannot read', () {
      final (forwards, invalid) = parsePuttyForwardings(
        'L0=a:1,Lx=a:1,L10=a,L10=:5,',
      );
      expect(forwards, isEmpty);
      expect(invalid, hasLength(4));
    });
  });

  group('to hosts and tunnels', () {
    final sessions = puttySessionsFrom(parseRegText(kPuttyReg));
    var n = 0;
    final changes = PuttyImport.changes(
      sessions,
      fallbackUsername: 'localme',
      now: DateTime.utc(2026),
      newId: () => 'id${n++}',
    );

    test('SSH sessions only', () {
      expect(changes.hosts.map((h) => h.label), [
        'My Server',
        'bastion',
        'Café box',
      ]);
    });

    test('no user name falls back to the local account', () {
      expect(
        changes.hosts.firstWhere((h) => h.label == 'Café box').username,
        'localme',
      );
    });

    test('forwards become tunnels that never start on their own', () {
      expect(changes.tunnels, hasLength(4));
      expect(changes.tunnels.every((t) => !t.autoStart), isTrue);
      final myServer = changes.hosts.first;
      expect(changes.tunnels.every((t) => t.hostId == myServer.id), isTrue);
      expect(changes.tunnels.first.listenHost, Tunnel.defaultListenHost);
      expect(changes.tunnels.first.label, 'PuTTY L8080=localhost:80');
    });

    test('no key is linked', () {
      expect(changes.hosts.every((h) => h.identityId == null), isTrue);
    });
  });

  test('a session already saved is marked', () {
    final saved = SshHost(
      id: 'x',
      label: 'x',
      hostname: 'MYSERVER.example.com',
      username: 'admin',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final candidates = PuttyImport.candidates(utf16leWithBom(kPuttyReg), [
      saved,
    ]);
    expect(
      candidates.firstWhere((c) => c.session.name == 'My Server').alreadySaved,
      isTrue,
    );
    expect(
      candidates.firstWhere((c) => c.session.name == 'bastion').alreadySaved,
      isFalse,
    );
  });

  group('the registry reader', () {
    test('asks reg.exe for the PuTTY key and reads what it wrote', () async {
      late List<String> args;
      final reader = PuttyRegistryReader(
        run: (exe, arguments) async {
          args = arguments;
          await File(arguments[2]).writeAsBytes(utf16leWithBom(kPuttyReg));
          return ProcessResult(0, 0, '', '');
        },
      );
      final bytes = await reader.export();
      expect(args.first, 'export');
      expect(args[1], r'HKCU\Software\SimonTatham\PuTTY\Sessions');
      expect(args.last, '/y');
      expect(decodeRegBytes(bytes!), contains('myserver.example.com'));
      // The temporary file is gone.
      expect(File(args[2]).existsSync(), isFalse);
    });

    test('no PuTTY key is nothing, not an error', () async {
      final reader = PuttyRegistryReader(
        run: (_, _) async => ProcessResult(0, 1, '', 'unable to find'),
      );
      expect(await reader.export(), isNull);
    });
  });
}
