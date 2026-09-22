import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/domain/http_guard.dart';

void main() {
  test('only loopback peers are accepted', () {
    expect(isLoopbackPeer(InternetAddress.loopbackIPv4), isTrue);
    expect(isLoopbackPeer(InternetAddress.loopbackIPv6), isTrue);
    expect(isLoopbackPeer(InternetAddress('192.168.1.20')), isFalse);
    expect(isLoopbackPeer(InternetAddress('10.0.0.1')), isFalse);
    expect(isLoopbackPeer(null), isFalse);
  });

  test('the Host header must name loopback on our port', () {
    expect(isAllowedHostHeader('127.0.0.1:47832', 47832), isTrue);
    expect(isAllowedHostHeader('LOCALHOST:47832', 47832), isTrue);
    expect(isAllowedHostHeader('[::1]:47832', 47832), isTrue);
    // DNS rebinding: a hostile name resolved to 127.0.0.1.
    expect(isAllowedHostHeader('evil.example:47832', 47832), isFalse);
    expect(isAllowedHostHeader('127.0.0.1:1234', 47832), isFalse);
    expect(isAllowedHostHeader('127.0.0.1', 47832), isFalse);
    expect(isAllowedHostHeader(null, 47832), isFalse);
  });

  test('any Origin at all is refused', () {
    expect(isAllowedOrigin(null), isTrue);
    expect(isAllowedOrigin('https://evil.example'), isFalse);
    expect(isAllowedOrigin('http://localhost:3000'), isFalse);
    expect(isAllowedOrigin('null'), isFalse);
  });

  test('reads a bearer token, case-insensitively, and nothing else', () {
    expect(bearerToken('Bearer abc'), 'abc');
    expect(bearerToken('bearer   abc  '), 'abc');
    expect(bearerToken('Basic abc'), isNull);
    expect(bearerToken('Bearer'), isNull);
    expect(bearerToken('Bearer a b'), isNull);
    expect(bearerToken(null), isNull);
  });

  test('constant-time comparison is still a comparison', () {
    expect(constantTimeEquals('secret', 'secret'), isTrue);
    expect(constantTimeEquals('secreT', 'secret'), isFalse);
    expect(constantTimeEquals('secre', 'secret'), isFalse);
    expect(constantTimeEquals('secrets', 'secret'), isFalse);
    expect(constantTimeEquals('', 'secret'), isFalse);
  });

  test('tokens are 32 random bytes, url-safe, unpadded', () {
    final token = generateMcpToken();
    expect(token, hasLength(43));
    expect(token, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(generateMcpToken(), isNot(token));
    // Deterministic with a seeded source, so the encoding is pinned.
    expect(generateMcpToken(Random(1)), generateMcpToken(Random(1)));
  });
}
