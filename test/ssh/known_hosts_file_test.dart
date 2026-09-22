import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/known_hosts_file.dart';

import 'fixtures/known_hosts_fixture.dart';

void main() {
  group('parseKnownHosts on the rich fixture', () {
    final result = parseKnownHosts(kKnownHostsFixture);
    List<String> addresses() => [
      for (final e in result.entries)
        e.isHashed ? 'hashed@${e.line}' : '${e.host}:${e.port}',
    ];

    test('reads plain names, brackets with ports, and comma lists', () {
      expect(addresses(), [
        'plain.example.com:22',
        // Lowercased, the way OpenSSH compares names.
        'multi.example.com:22',
        '10.0.0.5:22',
        'multi.example.com:2200',
        'bastion.example.net:2222',
        'hashed@6',
        'hashed@7',
        'exact.example.com:22',
        'plain.example.com:22',
      ]);
    });

    test('keeps each key type and its line', () {
      final byLine = {for (final e in result.entries) e.line: e.keyType};
      expect(byLine[3], 'ssh-ed25519');
      expect(byLine[4], 'ecdsa-sha2-nistp256');
      expect(byLine[5], 'ssh-rsa');
      expect(byLine[16], 'ssh-rsa');
    });

    test('fingerprints match what ssh-keygen -lf printed', () {
      final byLine = {for (final e in result.entries) e.line: e.fingerprint};
      expect(byLine[3], kEd25519Fingerprint);
      expect(byLine[4], kEcdsaFingerprint);
      expect(byLine[5], kRsaFingerprint);
    });

    test('hashed entries keep the whole |1|salt|hash name and port 0', () {
      final hashed = result.entries.where((e) => e.isHashed).toList();
      expect(hashed.map((e) => e.host), [
        kHashedExampleCom,
        kHashedExampleOrg2222,
      ]);
      expect(hashed.every((e) => e.port == 0), isTrue);
    });

    test('reports markers, unsupported types and bad lines by number', () {
      expect(result.skipped[KnownHostsSkip.revoked], [9]);
      expect(result.skipped[KnownHostsSkip.certAuthority], [10]);
      expect(result.skipped[KnownHostsSkip.unsupportedKeyType], [11]);
      expect(result.skipped[KnownHostsSkip.malformed], [12, 13, 14, 15, 17]);
    });

    test('counts wildcard and negated names without dropping the rest', () {
      expect(result.wildcardNames, 2);
      expect(addresses(), contains('exact.example.com:22'));
    });
  });

  group('parseKnownHosts edge cases', () {
    test('an empty file, or only comments, is nothing', () {
      final result = parseKnownHosts('\n# nothing\n   \n');
      expect(result.entries, isEmpty);
      expect(result.skipped, isEmpty);
    });

    test('CRLF line endings read the same as LF', () {
      final result = parseKnownHosts(
        'a.example ssh-ed25519 $kEd25519Key\r\n'
        'b.example ssh-ed25519 $kEd25519Key\r\n',
      );
      expect(result.entries.map((e) => e.host), ['a.example', 'b.example']);
    });

    test('a port out of range makes the name unreadable', () {
      final result = parseKnownHosts(
        '[x.example]:70000 ssh-ed25519 $kEd25519Key',
      );
      expect(result.entries, isEmpty);
      expect(result.skipped[KnownHostsSkip.malformed], [1]);
    });

    test('a malformed hashed name is a bad line, not a host', () {
      final result = parseKnownHosts('|1|nope ssh-ed25519 $kEd25519Key');
      expect(result.entries, isEmpty);
      expect(result.skipped[KnownHostsSkip.malformed], [1]);
    });
  });

  group('hashedNameMatches', () {
    test('matches OpenSSH-hashed names, port included', () {
      expect(hashedNameMatches(kHashedExampleCom, 'example.com'), isTrue);
      expect(
        hashedNameMatches(kHashedExampleOrg2222, '[example.org]:2222'),
        isTrue,
      );
    });

    test('does not match other names or ports', () {
      expect(hashedNameMatches(kHashedExampleCom, 'example.org'), isFalse);
      expect(hashedNameMatches(kHashedExampleOrg2222, 'example.org'), isFalse);
      expect(
        hashedNameMatches(kHashedExampleOrg2222, '[example.org]:22'),
        isFalse,
      );
    });

    test('garbage is simply no match', () {
      expect(hashedNameMatches('|1|x|y', 'example.com'), isFalse);
      expect(hashedNameMatches('example.com', 'example.com'), isFalse);
    });
  });

  test('knownHostsName brackets only non-default ports', () {
    expect(knownHostsName('h', 22), 'h');
    expect(knownHostsName('h', 2222), '[h]:2222');
  });

  test('hostKeyFingerprint is SHA-256 of the blob, unpadded base64', () {
    final blob = Uint8List.fromList(base64.decode(kEd25519Key));
    expect(hostKeyFingerprint(blob), kEd25519Fingerprint);
  });

  test('hostKeyFamily folds RSA signature algorithms into ssh-rsa', () {
    expect(hostKeyFamily('rsa-sha2-512'), 'ssh-rsa');
    expect(hostKeyFamily('rsa-sha2-256'), 'ssh-rsa');
    expect(hostKeyFamily('ssh-rsa'), 'ssh-rsa');
    expect(hostKeyFamily('ssh-ed25519'), 'ssh-ed25519');
  });
}
