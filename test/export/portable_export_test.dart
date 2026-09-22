import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/export/domain/portable_export.dart';

import 'sample_config.dart';

void main() {
  const fixture = 'test/export/fixtures/export_v1.json';

  test('the export matches the golden file byte for byte', () {
    final text = sampleExport().encode();
    // `flutter test --update-goldens` rewrites it, like any golden.
    if (autoUpdateGoldenFiles) File(fixture).writeAsStringSync(text);
    expect(text, File(fixture).readAsStringSync().replaceAll('\r\n', '\n'));
  });

  test('the order of the input does not change the output', () {
    final shuffled = sampleExport();
    final reversed = PortableExport(
      exportedAt: shuffled.exportedAt,
      app: shuffled.app,
      groups: shuffled.groups.reversed.toList(),
      identities: shuffled.identities.reversed.toList(),
      hosts: shuffled.hosts.reversed.toList(),
      tunnels: shuffled.tunnels.reversed.toList(),
      snippets: shuffled.snippets.reversed.toList(),
      knownHosts: shuffled.knownHosts.reversed.toList(),
    );
    expect(reversed.encode(), shuffled.encode());
  });

  test('says it holds no secrets, and holds none', () {
    final json = jsonDecode(sampleExport().encode()) as Map<String, Object?>;
    expect(json['format'], 'sshetu-export');
    expect(json['version'], 1);
    expect(json['containsSecrets'], isFalse);
    final identity = (json['identities']! as List).single as Map;
    expect(identity.keys, [
      'id',
      'label',
      'keyType',
      'publicKey',
      'fingerprint',
      'hasPassphrase',
      'origin',
      'createdAt',
      'updatedAt',
    ]);
    final keys = <String>{};
    void collect(Object? node) {
      if (node is Map) {
        for (final entry in node.entries) {
          keys.add(entry.key as String);
          collect(entry.value);
        }
      } else if (node is List) {
        node.forEach(collect);
      }
    }

    collect(json);
    for (final forbidden in [
      'privateKey',
      'password',
      'passphrase',
      'secret',
    ]) {
      expect(keys, isNot(contains(forbidden)));
    }
    expect(sampleExport().encode(), isNot(contains('PRIVATE KEY')));
  });

  test('reads back exactly what it wrote', () {
    final text = sampleExport().encode();
    expect(PortableExport.decode(text).encode(), text);
  });

  test('a host carries its key fingerprint', () {
    final decoded = PortableExport.decode(sampleExport().encode());
    final webHost = decoded.hosts.firstWhere((h) => h.id == 'h-web');
    expect(decoded.fingerprintForHost(webHost), identity.fingerprint);
    expect(identity.fingerprint, startsWith('SHA256:'));
  });

  group('versions', () {
    Map<String, Object?> base() =>
        jsonDecode(sampleExport().encode()) as Map<String, Object?>;

    test('version 1 is accepted', () {
      expect(() => PortableExport.fromJson(base()), returnsNormally);
    });

    test('a newer version is refused, naming it', () {
      final json = base()..['version'] = 2;
      expect(
        () => PortableExport.fromJson(json),
        throwsA(
          isA<PortableExportException>()
              .having(
                (e) => e.problem,
                'problem',
                PortableExportProblem.newerVersion,
              )
              .having((e) => e.version, 'version', 2),
        ),
      );
    });

    for (final bad in [0, -1, '1', 1.5, null]) {
      test('version $bad is not a version', () {
        final json = base()..['version'] = bad;
        expect(
          () => PortableExport.fromJson(json),
          throwsA(
            isA<PortableExportException>().having(
              (e) => e.problem,
              'problem',
              PortableExportProblem.invalidVersion,
            ),
          ),
        );
      });
    }
  });

  group('refuses what is not an export', () {
    PortableExportProblem problemOf(String text) {
      try {
        PortableExport.decode(text);
      } on PortableExportException catch (e) {
        return e.problem;
      }
      fail('decoded $text');
    }

    test('not JSON', () {
      expect(
        problemOf('Host web\n  HostName x'),
        PortableExportProblem.notJson,
      );
      expect(problemOf('[1, 2]'), PortableExportProblem.notJson);
    });

    test('someone else\'s JSON', () {
      expect(
        problemOf('{"format": "sshetu.backup", "version": 1}'),
        PortableExportProblem.notAnExport,
      );
      expect(problemOf('{"hosts": []}'), PortableExportProblem.notAnExport);
    });

    test('a broken entry, by path', () {
      final json = jsonDecode(sampleExport().encode()) as Map<String, Object?>;
      ((json['hosts']! as List)[1] as Map).remove('hostname');
      expect(
        () => PortableExport.fromJson(json),
        throwsA(
          isA<PortableExportException>()
              .having(
                (e) => e.problem,
                'problem',
                PortableExportProblem.malformed,
              )
              .having((e) => e.detail, 'detail', 'hosts[1].hostname'),
        ),
      );
    });

    test('a port out of range', () {
      final json = jsonDecode(sampleExport().encode()) as Map<String, Object?>;
      ((json['hosts']! as List)[0] as Map)['port'] = 70000;
      expect(
        () => PortableExport.fromJson(json),
        throwsA(
          isA<PortableExportException>().having(
            (e) => e.detail,
            'detail',
            'hosts[0].port',
          ),
        ),
      );
    });
  });

  group('is lenient where it can be', () {
    test('a minimal hand-written file', () {
      final decoded = PortableExport.decode('''
{"format": "sshetu-export", "version": 1, "hosts": [
  {"id": "a", "label": "a", "hostname": "a.example", "username": "me"}
]}''');
      final host = decoded.hosts.single;
      expect(host.port, 22);
      expect(host.keepaliveSeconds, 30);
      expect(decoded.groups, isEmpty);
      expect(decoded.knownHosts, isEmpty);
    });

    test('a UTF-8 byte-order mark', () {
      final text = '\u{FEFF}${sampleExport().encode()}';
      expect(PortableExport.decode(text).hosts, hasLength(2));
    });

    test('an environment variable the editor would refuse is dropped', () {
      final json = jsonDecode(sampleExport().encode()) as Map<String, Object?>;
      ((json['hosts']! as List)[1] as Map)['envVars'] = {
        'GOOD': 'yes',
        'BAD NAME': 'x',
        'MULTI': 'a\nb',
      };
      final host = PortableExport.fromJson(json).hosts
          .firstWhere((h) => h.id == 'h-web');
      expect(host.envVars, {'GOOD': 'yes'});
    });
  });
}
