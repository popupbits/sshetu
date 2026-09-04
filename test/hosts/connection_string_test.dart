import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/domain/connection_string.dart';

/// Reading the one string people actually have.
///
/// Nobody keeps a host, a user and a port in three separate places — they have
/// a line out of a wiki or a terminal. Every shape below is one somebody has
/// pasted at an SSH client and expected to work.
void main() {
  ({String? user, String host, int? port}) parse(String input) {
    final parsed = parseConnection(input);
    expect(parsed, isNotNull, reason: input);
    return (
      user: parsed!.username,
      host: parsed.hostname,
      port: parsed.port,
    );
  }

  test('a bare address', () {
    expect(parse('192.168.1.10'), (user: null, host: '192.168.1.10', port: null));
  });

  test('user@host, the commonest thing anyone types', () {
    expect(parse('root@192.168.1.10'), (
      user: 'root',
      host: '192.168.1.10',
      port: null,
    ));
  });

  test('a pasted ssh command', () {
    expect(parse('ssh root@192.168.1.10'), (
      user: 'root',
      host: '192.168.1.10',
      port: null,
    ));
  });

  test('with a port, either way round', () {
    const expected = (user: 'root', host: 'example.com', port: 2222);
    expect(parse('ssh -p 2222 root@example.com'), expected);
    expect(parse('ssh root@example.com -p 2222'), expected);
    expect(parse('ssh -p2222 root@example.com'), expected);
    expect(parse('root@example.com:2222'), expected);
  });

  test('a url', () {
    expect(parse('ssh://root@example.com:2222'), (
      user: 'root',
      host: 'example.com',
      port: 2222,
    ));
  });

  test('-l names the user the other way', () {
    expect(parse('ssh -l root example.com'), (
      user: 'root',
      host: 'example.com',
      port: null,
    ));
  });

  test('flags that take a value do not become the hostname', () {
    // `-J bastion` is the trap: read naively, "bastion" becomes the host and
    // the real destination is dropped.
    expect(parse('ssh -J bastion root@target.internal'), (
      user: 'root',
      host: 'target.internal',
      port: null,
    ));
    expect(parse('ssh -o StrictHostKeyChecking=no root@target'), (
      user: 'root',
      host: 'target',
      port: null,
    ));
  });

  test('an identity file is noticed but not mistaken for a host', () {
    final parsed = parseConnection('ssh root@host -i ~/.ssh/id_ed25519');

    expect(parsed!.hostname, 'host');
    expect(parsed.identityFile, '~/.ssh/id_ed25519');
  });

  test('an IPv6 address keeps its colons', () {
    expect(parse('root@[2001:db8::1]:2222'), (
      user: 'root',
      host: '2001:db8::1',
      port: 2222,
    ));
    expect(parse('2001:db8::1'), (
      user: null,
      host: '2001:db8::1',
      port: null,
    ));
  });

  test('a username containing an @ still works', () {
    expect(parse('me@corp.com@jump.example.com'), (
      user: 'me@corp.com',
      host: 'jump.example.com',
      port: null,
    ));
  });

  test('surrounding whitespace is not the user\'s problem', () {
    expect(parse('   ssh  root@example.com  '), (
      user: 'root',
      host: 'example.com',
      port: null,
    ));
  });

  test('a port that cannot be one is dropped, not saved', () {
    // Better an empty port field than a host row that cannot be dialled.
    expect(parseConnection('root@host:99999')?.port, isNull);
    expect(parseConnection('root@host:0')?.port, isNull);
    expect(parseConnection('ssh -p abc root@host')?.port, isNull);
  });

  test('nothing usable returns nothing, rather than a guess', () {
    for (final input in ['', '   ', 'ssh', '@', 'ssh -p 22']) {
      expect(parseConnection(input), isNull, reason: '"$input"');
    }
  });

  test('a hostname containing "ssh" survives', () {
    expect(parse('ssh.example.com'), (
      user: null,
      host: 'ssh.example.com',
      port: null,
    ));
    expect(parse('ssh git@ssh.github.com'), (
      user: 'git',
      host: 'ssh.github.com',
      port: null,
    ));
  });
}
