import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/tunnels/domain/free_port.dart';

void main() {
  Future<bool> Function(int) busy(Set<int> taken, List<int> tried) =>
      (port) async {
        tried.add(port);
        return !taken.contains(port);
      };

  test('the same port when it is free', () async {
    final tried = <int>[];
    expect(await pickLocalPort(3000, canBind: busy({}, tried)), 3000);
    expect(tried, [3000]);
  });

  test('the next free one when it is taken', () async {
    final tried = <int>[];
    expect(await pickLocalPort(3000, canBind: busy({3000, 3001}, tried)), 3002);
    expect(tried, [3000, 3001, 3002]);
  });

  test('null after the attempts run out', () async {
    final tried = <int>[];
    expect(
      await pickLocalPort(
        80,
        attempts: 3,
        canBind: busy({80, 81, 82, 83}, tried),
      ),
      isNull,
    );
    expect(tried, [80, 81, 82]);
  });

  test('never past 65535', () async {
    final tried = <int>[];
    expect(
      await pickLocalPort(65534, canBind: busy({65534, 65535}, tried)),
      isNull,
    );
    expect(tried, [65534, 65535]);
  });

  test('canBindLoopback sees a port held by someone else', () async {
    final held = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(held.close);
    expect(await canBindLoopback(held.port), isFalse);
    expect(await pickLocalPort(held.port), isNot(held.port));
  });
}
