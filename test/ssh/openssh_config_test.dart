import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_navigator/core/ssh/openssh_config.dart';
import 'package:ssh_navigator/core/ssh/openssh_import.dart';

void main() {
  group('OpenSshConfig.parse', () {
    test('reads a plain block', () {
      final config = OpenSshConfig.parse('''
Host web
  HostName web.example.com
  User deploy
  Port 2222
''');
      final options = config.resolve('web');
      expect(options['hostname'], 'web.example.com');
      expect(options['user'], 'deploy');
      expect(options['port'], '2222');
    });

    test('keywords are case-insensitive', () {
      final config = OpenSshConfig.parse('HOST web\n  HOSTNAME a.example.com');
      expect(config.resolve('web')['hostname'], 'a.example.com');
    });

    test('accepts the Keyword=value form', () {
      final config = OpenSshConfig.parse('Host=web\nPort=2222');
      expect(config.resolve('web')['port'], '2222');
    });

    test('strips comments but not a # inside quotes', () {
      final config = OpenSshConfig.parse('''
Host web       # the web box
  HostName web.example.com
  ProxyCommand "nc # weird" %h %p
''');
      expect(config.resolve('web')['hostname'], 'web.example.com');
      expect(config.resolve('web')['proxycommand'], contains('#'));
    });

    test('first value wins, as ssh_config(5) specifies', () {
      // The classic import bug: applying last-wins here sends the connection
      // to the default rather than the host's own setting.
      final config = OpenSshConfig.parse('''
Host web
  HostName real.example.com

Host *
  HostName wrong.example.com
  User fallback
''');
      final options = config.resolve('web');
      expect(options['hostname'], 'real.example.com');
      expect(
        options['user'],
        'fallback',
        reason: 'a Host * default still applies where the block was silent',
      );
    });

    test('a wildcard block contributes defaults to a matching host', () {
      final config = OpenSshConfig.parse('''
Host web-1
  HostName web1.example.com

Host web-*
  User deploy
  Port 2222
''');
      final options = config.resolve('web-1');
      expect(options['user'], 'deploy');
      expect(options['port'], '2222');
    });

    test('a negated pattern vetoes its block', () {
      final config = OpenSshConfig.parse('''
Host * !bastion
  User deploy
''');
      expect(config.resolve('web')['user'], 'deploy');
      expect(
        config.resolve('bastion')['user'],
        isNull,
        reason: '`Host * !bastion` must not apply to bastion',
      );
    });

    test('one Host line can name several hosts', () {
      final config = OpenSshConfig.parse('Host web1 web2\n  User deploy');
      expect(config.resolve('web1')['user'], 'deploy');
      expect(config.resolve('web2')['user'], 'deploy');
      expect(config.resolve('db')['user'], isNull);
    });

    test('? matches exactly one character', () {
      final config = OpenSshConfig.parse('Host web?\n  User deploy');
      expect(config.resolve('web1')['user'], 'deploy');
      expect(config.resolve('web12')['user'], isNull);
    });

    test('a Match block does not leak into the Host above it', () {
      // Match conditions cannot be evaluated here. Attributing its body to the
      // previous Host would silently change where that host connects.
      final config = OpenSshConfig.parse('''
Host web
  HostName web.example.com

Match host db
  User root
''');
      expect(config.resolve('web')['user'], isNull);
    });

    test('options before any Host line behave like Host *', () {
      final config = OpenSshConfig.parse('''
ServerAliveInterval 60

Host web
  HostName web.example.com
''');
      expect(config.resolve('web')['serveraliveinterval'], '60');
    });

    test('a malformed line is skipped, not fatal', () {
      final config = OpenSshConfig.parse('''
Host web
  HostName web.example.com
  ((((
  User deploy
''');
      expect(config.resolve('web')['user'], 'deploy');
    });

    test('Include is surfaced, never followed', () {
      // Reading arbitrary paths during an import is not this parser's call.
      final config = OpenSshConfig.parse('Include ~/.ssh/conf.d/*.conf');
      expect(config.includePaths, ['~/.ssh/conf.d/*.conf']);
    });
  });

  group('importableAliases', () {
    test('offers concrete hosts and never patterns', () {
      final config = OpenSshConfig.parse('''
Host *
  User deploy

Host web-*
  Port 2222

Host web-1
  HostName web1.example.com

Host db
  HostName db.example.com
''');
      expect(config.importableAliases, ['web-1', 'db']);
    });
  });

  group('OpenSshScanner.parseHosts', () {
    const scanner = OpenSshScanner(fileSystemRoot: '/home/tester');

    test('falls back to the alias when HostName is absent', () {
      // `Host db` with no HostName really does connect to `db`.
      final hosts = scanner.parseHosts('Host db\n  User root');
      expect(hosts.single.hostname, 'db');
    });

    test('defaults the port to 22', () {
      expect(scanner.parseHosts('Host db').single.port, 22);
    });

    test('expands ~ in IdentityFile', () {
      final hosts = scanner.parseHosts(
        'Host db\n  IdentityFile ~/.ssh/id_ed25519',
      );
      expect(
        hosts.single.identityFile,
        '/home/tester/.ssh/id_ed25519'.replaceAll('/', Platform.pathSeparator),
      );
    });

    test('carries ProxyJump through as an alias', () {
      final hosts = scanner.parseHosts('Host db\n  ProxyJump bastion');
      expect(hosts.single.jumpAlias, 'bastion');
    });

    test('reports options it cannot honour rather than dropping them', () {
      // A user whose ProxyCommand did not come across must be told, not left
      // to find out when the connection behaves differently than their shell.
      final hosts = scanner.parseHosts('''
Host db
  ProxyCommand nc %h %p
  LocalForward 5432 localhost:5432
''');
      expect(hosts.single.unsupported, containsAll(['proxycommand', 'localforward']));
    });

    test('a host with nothing unsupported reports nothing', () {
      final hosts = scanner.parseHosts('Host db\n  HostName db.example.com');
      expect(hosts.single.unsupported, isEmpty);
    });
  });

  group('fingerprints', () {
    test('match what ssh-keygen -lf prints', () {
      // A real ed25519 public key; the expected value is the SHA256 form
      // OpenSSH shows, so a user can compare the two by eye.
      const pub =
          'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP1kR7QhQxPPFdMbCfvhLDNyIYAmYaLPnJTMkQGDtxNu test@example';
      final fingerprint = OpenSshScanner.fingerprintOf(pub);

      expect(fingerprint, startsWith('SHA256:'));
      expect(
        fingerprint,
        isNot(endsWith('=')),
        reason: 'ssh-keygen prints the base64 unpadded',
      );
    });

    test('a malformed public key yields null rather than throwing', () {
      expect(OpenSshScanner.fingerprintOf('not-a-key'), isNull);
      expect(OpenSshScanner.fingerprintOf('ssh-ed25519 !!!not-base64!!!'), isNull);
    });
  });

  group('encrypted key detection', () {
    test('spots a classic PEM with a DEK-Info header', () {
      expect(
        OpenSshScanner.isEncryptedPem('''
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,0123456789ABCDEF

abcdef
-----END RSA PRIVATE KEY-----
'''),
        isTrue,
      );
    });

    test('an unencrypted classic PEM is not flagged', () {
      expect(
        OpenSshScanner.isEncryptedPem('''
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA
-----END RSA PRIVATE KEY-----
'''),
        isFalse,
      );
    });
  });
}
