import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/mcp/domain/json_rpc.dart';

void main() {
  JsonRpcException failure(Object? body) {
    try {
      parseJsonRpc(body);
    } on JsonRpcException catch (e) {
      return e;
    }
    fail('expected a JsonRpcException for $body');
  }

  test('reads a request with an integer or string id', () {
    final a = parseJsonRpc({
      'jsonrpc': '2.0',
      'id': 7,
      'method': 'tools/list',
      'params': {'cursor': 'x'},
    });
    expect(a.id, 7);
    expect(a.isNotification, isFalse);
    expect(a.params['cursor'], 'x');

    final b = parseJsonRpc({'jsonrpc': '2.0', 'id': 'abc', 'method': 'ping'});
    expect(b.id, 'abc');
    expect(b.params, isEmpty);
  });

  test('a message without an id is a notification', () {
    final n = parseJsonRpc({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    expect(n.isNotification, isTrue);
  });

  test('refuses batches, non-objects and the wrong version', () {
    expect(failure([]).code, JsonRpcCodes.invalidRequest);
    expect(failure('ping').code, JsonRpcCodes.invalidRequest);
    expect(
      failure({'jsonrpc': '1.0', 'id': 1, 'method': 'ping'}).code,
      JsonRpcCodes.invalidRequest,
    );
  });

  test('refuses a null, fractional or object id', () {
    for (final id in [null, 1.5, <String, Object?>{}]) {
      expect(
        failure({'jsonrpc': '2.0', 'id': id, 'method': 'ping'}).code,
        JsonRpcCodes.invalidRequest,
        reason: 'id $id',
      );
    }
  });

  test('refuses a missing method, a response, and array params', () {
    expect(
      failure({'jsonrpc': '2.0', 'id': 1}).code,
      JsonRpcCodes.invalidRequest,
    );
    final response = failure({'jsonrpc': '2.0', 'id': 1, 'result': {}});
    expect(response.message, contains('takes no responses'));
    final params = failure({
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'ping',
      'params': [1],
    });
    expect(params.id, 3, reason: 'the id is echoed when it could be read');
  });

  test('an error response leaves out an id it does not have', () {
    expect(jsonRpcError(null, -32600, 'bad'), {
      'jsonrpc': '2.0',
      'error': {'code': -32600, 'message': 'bad'},
    });
    expect(jsonRpcError(4, -1, 'x', data: {'a': 1})['id'], 4);
  });
}
