import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/ssh/key_generator.dart';
import 'package:sshetu/core/ssh/ssh_connection.dart';

/// The agent-forwarding plumbing: what [agentHandlerFor] hands dartssh2, and
/// that the agent it builds answers a forwarded request with our keys.
///
/// No UI and no setting yet — a per-host switch needs a column — so this is
/// the half that can be proved now.
void main() {
  SSHKeyPair pairOf(GeneratedKey key) =>
      SSHKeyPair.fromPem(key.privateKey).single;

  Uint8List string(List<int> bytes) {
    final out = BytesBuilder()
      ..add((ByteData(4)..setUint32(0, bytes.length)).buffer.asUint8List())
      ..add(bytes);
    return out.toBytes();
  }

  Uint8List uint32(int value) =>
      (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

  /// A tiny reader for agent replies.
  (int, List<Uint8List>) readReply(Uint8List reply) {
    final data = ByteData.sublistView(reply);
    var offset = 1;
    final strings = <Uint8List>[];
    if (reply[0] == SSHAgentProtocol.identitiesAnswer) {
      final count = data.getUint32(offset);
      offset += 4;
      for (var i = 0; i < count; i++) {
        final length = data.getUint32(offset);
        offset += 4;
        strings.add(reply.sublist(offset, offset + length));
        offset += length;
        final commentLength = data.getUint32(offset);
        offset += 4 + commentLength;
      }
    } else if (reply[0] == SSHAgentProtocol.signResponse) {
      final length = data.getUint32(offset);
      offset += 4;
      strings.add(reply.sublist(offset, offset + length));
    }
    return (reply[0], strings);
  }

  group('agentHandlerFor', () {
    final key = pairOf(SshKeyGenerator.ed25519());

    test('is off unless asked for', () {
      expect(agentHandlerFor([key], forward: false), isNull);
    });

    test('is off with nothing to offer', () {
      // A password host has no keys; asking the server for forwarding would
      // only risk a refusal that dartssh2 treats as fatal to the channel.
      expect(agentHandlerFor(null, forward: true), isNull);
      expect(agentHandlerFor(const [], forward: true), isNull);
    });

    test('is an agent over the given keys when on', () {
      expect(agentHandlerFor([key], forward: true), isA<SSHKeyPairAgent>());
    });
  });

  group('the forwarded agent', () {
    final ed = pairOf(SshKeyGenerator.ed25519(comment: 'ed'));
    final ec = pairOf(SshKeyGenerator.generate(SshKeyType.ecdsaP256));
    late SSHKeyPair rsa;
    late SSHAgentHandler agent;

    setUpAll(() {
      rsa = pairOf(SshKeyGenerator.generate(SshKeyType.rsa3072));
      agent = agentHandlerFor([ed, ec, rsa], forward: true)!;
    });

    test('lists exactly our public keys', () async {
      final reply = await agent.handleRequest(
        Uint8List.fromList([SSHAgentProtocol.requestIdentities]),
      );
      final (type, blobs) = readReply(reply);
      expect(type, SSHAgentProtocol.identitiesAnswer);
      expect(blobs, [
        ed.toPublicKey().encode(),
        ec.toPublicKey().encode(),
        rsa.toPublicKey().encode(),
      ]);
    });

    Future<Uint8List?> sign(SSHKeyPair pair, List<int> data, int flags) async {
      final request = BytesBuilder()
        ..addByte(SSHAgentProtocol.signRequest)
        ..add(string(pair.toPublicKey().encode()))
        ..add(string(data))
        ..add(uint32(flags));
      final (type, strings) = readReply(
        await agent.handleRequest(request.toBytes()),
      );
      return type == SSHAgentProtocol.signResponse ? strings.single : null;
    }

    final data = utf8.encode('session id + userauth request');

    test('signs with Ed25519 exactly as the key itself would', () async {
      // Ed25519 is deterministic, so the agent's signature must be the very
      // bytes the key produces when it authenticates directly.
      expect(
        await sign(ed, data, 0),
        ed.sign(Uint8List.fromList(data)).encode(),
      );
    });

    test(
      'signs with RSA as rsa-sha2-256 when the server asks for it',
      () async {
        final signature = await sign(rsa, data, SSHAgentProtocol.rsaSha2_256);
        expect(signature, rsa.sign(Uint8List.fromList(data)).encode());
        expect(SSHSignature.getType(signature!), 'rsa-sha2-256');
      },
    );

    test('signs with ECDSA, as ecdsa-sha2-nistp256', () async {
      final signature = await sign(ec, data, 0);
      expect(signature, isNotNull);
      expect(SSHSignature.getType(signature!), 'ecdsa-sha2-nistp256');
    });

    test('refuses a key it does not hold', () async {
      final stranger = pairOf(SshKeyGenerator.ed25519());
      expect(await sign(stranger, data, 0), isNull);
    });

    test('refuses requests it does not implement', () async {
      // SSH_AGENTC_ADD_IDENTITY: a remote host must never be able to plant a
      // key in this app.
      final reply = await agent.handleRequest(Uint8List.fromList([17]));
      expect(reply, [SSHAgentProtocol.failure]);
    });
  });
}
