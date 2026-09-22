import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/tunnels/domain/listening_ports.dart';

/// `ss -Htlnp` on Ubuntu 24.04 as an ordinary user: process names only for
/// the user's own processes.
const _ssWithProcesses = '''
LISTEN 0      4096   127.0.0.53%lo:53        0.0.0.0:*    users:(("systemd-resolve",pid=652,fd=14))
LISTEN 0      128          0.0.0.0:22        0.0.0.0:*
LISTEN 0      511        127.0.0.1:3000      0.0.0.0:*    users:(("node",pid=4242,fd=21))
LISTEN 0      4096      127.0.0.54:53        0.0.0.0:*
LISTEN 0      5            0.0.0.0:8000      0.0.0.0:*    users:(("python3",pid=5150,fd=3))
LISTEN 0      128             [::]:22           [::]:*
LISTEN 0      5               [::]:8000         [::]:*    users:(("python3",pid=5150,fd=4))
LISTEN 0      244            [::1]:5432         [::]:*
LISTEN 0      4096               *:9090            *:*
LISTEN 0      4096         0.0.0.0:5355      0.0.0.0:*
''';

/// `ss -tln` from an older iproute2: no `-H`, so a header, and no `-p`.
const _ssPlain = '''
State      Recv-Q Send-Q Local Address:Port               Peer Address:Port
LISTEN     0      128          *:22                       *:*
LISTEN     0      511    127.0.0.1:3000                     *:*
LISTEN     0      128         :::22                      :::*
LISTEN     0      128         :::8080                    :::*
''';

/// net-tools `netstat -tlnp` as an ordinary user.
const _netstatLinux = '''
(Not all processes could be identified, non-owned process info
 will not be shown, you would have to be root to see it all.)
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -
tcp        0      0 127.0.0.1:3000          0.0.0.0:*               LISTEN      4242/node
tcp        0      0 127.0.0.1:6379          0.0.0.0:*               LISTEN      -
tcp6       0      0 :::22                   :::*                    LISTEN      -
tcp6       0      0 :::8080                 :::*                    LISTEN      777/java: /usr/bin
''';

/// macOS `netstat -an -p tcp`: every connection, BSD `address.port`.
const _netstatBsd = '''
Active Internet connections (including servers)
Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
tcp4       0      0  127.0.0.1.3000         *.*                    LISTEN
tcp46      0      0  *.8080                 *.*                    LISTEN
tcp6       0      0  ::1.5432               *.*                    LISTEN
tcp4       0      0  192.168.1.5.52344      17.57.146.52.443       ESTABLISHED
''';

const _procTcp = '''
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 00000000:0016 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 12345 1 0000000000000000 100 0 0 10 0
   1: 0100007F:0BB8 00000000:0000 0A 00000000:00000000 00:00000000 00000000  1000        0 23456 1 0000000000000000 100 0 0 10 0
   2: 3500007F:0035 00000000:0000 0A 00000000:00000000 00:00000000 00000000   101        0 34567 1 0000000000000000 100 0 0 10 0
   3: 0100007F:0BB8 0100007F:D2F0 01 00000000:00000000 00:00000000 00000000  1000        0 45678 1 0000000000000000 20 4 30 10 -1
''';

const _procTcp6 = '''
  sl  local_address                         remote_address                        st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 00000000000000000000000000000000:1F90 00000000000000000000000000000000:0000 0A 00000000:00000000 00:00000000 00000000  1000        0 56789 1 0000000000000000 100 0 0 10 0
   1: 00000000000000000000000001000000:1538 00000000000000000000000000000000:0000 0A 00000000:00000000 00:00000000 00000000   113        0 67890 1 0000000000000000 100 0 0 10 0
   2: 0000000000000000FFFF00000100007F:2382 00000000000000000000000000000000:0000 0A 00000000:00000000 00:00000000 00000000  1000        0 78901 1 0000000000000000 100 0 0 10 0
''';

ListeningPort _port(List<ListeningPort> ports, int number) =>
    ports.firstWhere((p) => p.port == number);

void main() {
  group('splitHostPort', () {
    for (final (token, address, port) in const [
      ('0.0.0.0:22', '0.0.0.0', 22),
      ('*:80', '*', 80),
      ('[::]:22', '::', 22),
      ('[::1]:631', '::1', 631),
      (':::22', '::', 22),
      ('127.0.0.53%lo:53', '127.0.0.53', 53),
      ('[fe80::1%eth0]:5353', 'fe80::1', 5353),
      ('127.0.0.1.631', '127.0.0.1', 631),
      ('*.22', '*', 22),
      ('::1.5432', '::1', 5432),
    ]) {
      test(token, () {
        final split = splitHostPort(token)!;
        expect(split.address, address);
        expect(split.port, port);
      });
    }

    test('a wildcard or out-of-range port is not a port', () {
      expect(splitHostPort('0.0.0.0:*'), isNull);
      expect(splitHostPort('*.*'), isNull);
      expect(splitHostPort('0.0.0.0:70000'), isNull);
      expect(splitHostPort('LISTEN'), isNull);
    });
  });

  group('ss', () {
    test('with -p: every port, merged across addresses, with processes', () {
      final ports = parseSsOutput(_ssWithProcesses);
      expect(ports.map((p) => p.port), [22, 53, 3000, 5355, 5432, 8000, 9090]);

      final node = _port(ports, 3000);
      expect(node.process, 'node');
      expect(node.pid, 4242);
      expect(node.addresses, ['127.0.0.1']);
      expect(node.isLoopbackOnly, isTrue);

      final python = _port(ports, 8000);
      expect(python.addresses, ['0.0.0.0', '::']);
      expect(python.process, 'python3');
      expect(python.isWildcard, isTrue);
      expect(python.isLoopbackOnly, isFalse);

      // Both DNS stubs fold into one port 53.
      expect(_port(ports, 53).addresses, ['127.0.0.53', '127.0.0.54']);

      final postgres = _port(ports, 5432);
      expect(postgres.process, isNull);
      expect(postgres.addresses, ['::1']);
      expect(postgres.targetHost, '::1');

      expect(_port(ports, 9090).addresses, ['*']);
    });

    test('without -p and with a header', () {
      final ports = parseSsOutput(_ssPlain);
      expect(ports.map((p) => p.port), [22, 3000, 8080]);
      expect(ports.every((p) => p.process == null), isTrue);
      expect(_port(ports, 22).addresses, ['*', '::']);
      expect(_port(ports, 8080).addresses, ['::']);
    });

    test('junk and blank lines are skipped, CRLF is fine', () {
      final ports = parseSsOutput(
        'garbage here\r\n\r\nLISTEN 0 5 127.0.0.1:4000 0.0.0.0:*\r\n',
      );
      expect(ports.single.port, 4000);
    });
  });

  group('netstat', () {
    test('Linux -tlnp: processes where visible, "-" where not', () {
      final ports = parseNetstatOutput(_netstatLinux);
      expect(ports.map((p) => p.port), [22, 3000, 6379, 8080]);
      expect(_port(ports, 3000).process, 'node');
      expect(_port(ports, 3000).pid, 4242);
      expect(_port(ports, 6379).process, isNull);
      expect(_port(ports, 8080).process, 'java');
      expect(_port(ports, 22).addresses, ['0.0.0.0', '::']);
    });

    test('BSD -an: LISTEN rows only, dotted ports', () {
      final ports = parseNetstatOutput(_netstatBsd);
      expect(ports.map((p) => p.port), [3000, 5432, 8080]);
      expect(_port(ports, 3000).addresses, ['127.0.0.1']);
      expect(_port(ports, 5432).addresses, ['::1']);
      expect(_port(ports, 8080).addresses, ['*']);
    });
  });

  group('/proc/net/tcp', () {
    test('IPv4: listening rows decoded, established ones ignored', () {
      final ports = parseProcNetTcp(_procTcp);
      expect(ports.map((p) => p.port), [22, 53, 3000]);
      expect(_port(ports, 22).addresses, ['0.0.0.0']);
      expect(_port(ports, 53).addresses, ['127.0.0.53']);
      expect(_port(ports, 3000).addresses, ['127.0.0.1']);
      expect(ports.every((p) => p.process == null), isTrue);
    });

    test('IPv6: wildcard, loopback and IPv4-mapped loopback', () {
      final ports = parseProcNetTcp(_procTcp6);
      expect(ports.map((p) => p.port), [5432, 8080, 9090]);
      expect(_port(ports, 8080).addresses, ['::']);
      expect(_port(ports, 5432).addresses, ['::1']);
      expect(_port(ports, 9090).addresses, ['::ffff:7f00:1']);
      expect(_port(ports, 9090).isLoopbackOnly, isTrue);
    });

    test('decodeProcAddress', () {
      expect(decodeProcAddress('0100007F'), '127.0.0.1');
      expect(decodeProcAddress('00000000'), '0.0.0.0');
      expect(decodeProcAddress('0500A8C0'), '192.168.0.5');
      expect(decodeProcAddress('00000000000000000000000001000000'), '::1');
      expect(
        decodeProcAddress('000080FE00000000FF005450B6AD1DFE'),
        'fe80::5054:ff:fe1d:adb6',
      );
      expect(decodeProcAddress('xyz'), isNull);
      expect(decodeProcAddress('0100'), isNull);
    });
  });

  group('parsePortsOutput picks the parser its section names', () {
    test('ss', () {
      final ports = parsePortsOutput('banner\n@@sshetu:ss\n$_ssWithProcesses');
      expect(_port(ports, 3000).process, 'node');
    });

    test('netstat', () {
      final ports = parsePortsOutput('@@sshetu:netstat\n$_netstatLinux');
      expect(ports.map((p) => p.port), [22, 3000, 6379, 8080]);
    });

    test('/proc, both tables merged', () {
      final ports = parsePortsOutput(
        '@@sshetu:tcp\n$_procTcp\n@@sshetu:tcp6\n$_procTcp6',
      );
      expect(ports.map((p) => p.port), [22, 53, 3000, 5432, 8080, 9090]);
    });

    test('nothing at all', () {
      expect(parsePortsOutput(''), isEmpty);
    });
  });

  group('filtering', () {
    test('system ports go, everything else stays, sorted', () {
      final shown = visiblePorts(parseSsOutput(_ssWithProcesses));
      expect(shown.map((p) => p.port), [3000, 5432, 8000, 9090]);
    });

    test('the list is explicit and small', () {
      expect(ignoredSystemPorts, {22, 25, 53, 111, 631, 5355});
    });

    test('the connection\'s own sshd port is hidden too', () {
      final shown = visiblePorts(
        parseSsOutput(
          'LISTEN 0 5 0.0.0.0:2229 0.0.0.0:*\n'
          'LISTEN 0 5 0.0.0.0:80 0.0.0.0:*',
        ),
        alsoIgnore: {2229},
      );
      expect(shown.map((p) => p.port), [80]);
    });
  });

  group('targetHost', () {
    ListeningPort at(List<String> addresses) =>
        ListeningPort(port: 1, addresses: addresses);

    test('IPv4 loopback or any wildcard dials 127.0.0.1', () {
      expect(at(['127.0.0.1']).targetHost, '127.0.0.1');
      expect(at(['0.0.0.0']).targetHost, '127.0.0.1');
      expect(at(['::']).targetHost, '127.0.0.1');
      expect(at(['*']).targetHost, '127.0.0.1');
      expect(at(['::1', '127.0.0.1']).targetHost, '127.0.0.1');
    });

    test('IPv6 loopback only dials ::1', () {
      expect(at(['::1']).targetHost, '::1');
    });

    test('one specific address dials that address', () {
      expect(at(['10.0.0.5']).targetHost, '10.0.0.5');
    });
  });
}
