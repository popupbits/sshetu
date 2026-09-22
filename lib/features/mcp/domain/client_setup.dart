import 'dart:convert';

/// What Settings offers to paste into an MCP client. Built here, not in the
/// ARB files: it is code, and ICU would read its braces as placeholders.

String mcpEndpointUrl(int port) => 'http://127.0.0.1:$port/mcp';

/// The `claude mcp add` line for Claude Code.
String claudeCodeSetup(int port, String token) =>
    'claude mcp add --transport http sshetu ${mcpEndpointUrl(port)} '
    '--header "Authorization: Bearer $token"';

/// The `mcpServers` block most other clients read.
String jsonClientSetup(int port, String token) =>
    const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        'sshetu': {
          'type': 'http',
          'url': mcpEndpointUrl(port),
          'headers': {'Authorization': 'Bearer $token'},
        },
      },
    });

/// [token] as shown while hidden: enough to tell two apart, not enough to
/// use.
String maskToken(String token) => token.length <= 4
    ? '••••'
    : '${'•' * 12}${token.substring(token.length - 4)}';
