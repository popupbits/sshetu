import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import 'data/mcp_http_server.dart';
import 'domain/http_guard.dart';

/// The MCP integration's settings: whether the local server runs, the token
/// a client must present, and the port it asks for first.
///
/// **Why the token lives in shared_preferences, not the keychain.** It is a
/// capability for a server that listens on 127.0.0.1 only, and anything able
/// to read this app's preferences already runs as this user on this machine
/// — it could read the host list from the database just as well, and it
/// still cannot act without the user approving in SSHetu. The keychain would
/// add an OS prompt on macOS, and behind the app lock a biometric prompt, to
/// every launch with the integration on — for no protection the approval
/// dialog does not already give.
@immutable
class McpSettings {
  const McpSettings({
    this.enabled = false,
    this.token,
    this.port = kDefaultMcpPort,
  });

  /// Off unless the user turns it on. Always.
  final bool enabled;

  /// Generated the first time it is turned on; regenerated on request.
  final String? token;

  final int port;

  McpSettings copyWith({bool? enabled, String? token, int? port}) =>
      McpSettings(
        enabled: enabled ?? this.enabled,
        token: token ?? this.token,
        port: port ?? this.port,
      );

  @override
  bool operator ==(Object other) =>
      other is McpSettings &&
      other.enabled == enabled &&
      other.token == token &&
      other.port == port;

  @override
  int get hashCode => Object.hash(enabled, token, port);
}

/// Whether this platform can run the integration: desktop only. A platform
/// capability, not a layout decision — a phone has no MCP client beside it.
final mcpSupportedProvider = Provider<bool>(
  (ref) =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
);

const _keyEnabled = 'mcp.enabled';
const _keyToken = 'mcp.token';
const _keyPort = 'mcp.port';

class McpSettingsController extends Notifier<McpSettings> {
  @override
  McpSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T? read<T>(T? Function() get) {
      try {
        return get();
      } on Object {
        return null;
      }
    }

    final port = read(() => prefs.getInt(_keyPort));
    return McpSettings(
      enabled: read(() => prefs.getBool(_keyEnabled)) ?? false,
      token: read(() => prefs.getString(_keyToken)),
      port: port != null && port > 0 && port < 65536 ? port : kDefaultMcpPort,
    );
  }

  /// Turning it on for the first time makes a token.
  Future<void> setEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (value && state.token == null) {
      final token = generateMcpToken();
      await prefs.setString(_keyToken, token);
      state = state.copyWith(token: token);
    }
    state = state.copyWith(enabled: value);
    await prefs.setBool(_keyEnabled, value);
  }

  /// A new token. Every client configured with the old one stops working.
  Future<void> regenerateToken() async {
    final token = generateMcpToken();
    state = state.copyWith(token: token);
    await ref.read(sharedPreferencesProvider).setString(_keyToken, token);
  }
}

final mcpSettingsProvider =
    NotifierProvider<McpSettingsController, McpSettings>(
      McpSettingsController.new,
    );
