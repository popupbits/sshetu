import 'package:path/path.dart' as p;

import '../../snippets/domain/snippet_template.dart';
import 'approval.dart';
import 'mcp_backend.dart';
import 'mcp_tool.dart';

/// Every tool SSHetu offers an MCP client, over [backend].
///
/// Six read tools, which answer at once, and eight act tools, each of which
/// the dispatcher puts in front of the user first. Deterministic order —
/// clients cache the list.
List<McpTool> buildSshetuTools(
  McpBackend backend, {
  DateTime Function() clock = DateTime.now,
}) {
  SessionSummary sessionFor(ToolArgs args) {
    final id = args.requireString('session_id');
    for (final session in backend.sessions()) {
      if (session.id == id) return session;
    }
    throw McpToolException(
      'No open session with id "$id". Call list_sessions for the ids.',
    );
  }

  SessionSummary liveSessionFor(ToolArgs args) {
    final session = sessionFor(args);
    if (!session.isLive) {
      throw McpToolException(
        'Session "${session.id}" is not connected (it is ${session.status}).',
      );
    }
    return session;
  }

  Duration waitFrom(ToolArgs args, {required int fallback}) => Duration(
    seconds: args.optionalInt(
      'wait_seconds',
      fallback: fallback,
      min: 0,
      max: 30,
    ),
  );

  String limited(ToolArgs args, String name, int maxChars) {
    final value = args.requireString(name);
    if (value.length > maxChars) {
      throw McpToolException('"$name" is longer than $maxChars characters.');
    }
    return value;
  }

  McpToolResult outputResult(String output, Duration wait) => McpToolResult(
    output.trim().isEmpty
        ? '(no output within ${wait.inSeconds} s — read_terminal shows the '
              'screen as it is now)'
        : output,
  );

  String localPathFrom(ToolArgs args) {
    final path = args.requireString('local_path');
    if (!p.isAbsolute(path)) {
      throw const McpToolException('"local_path" must be an absolute path.');
    }
    return path;
  }

  return [
    // ---------------------------------------------------------------- read
    McpTool.read(
      name: 'list_hosts',
      title: 'List saved hosts',
      description:
          'Lists the servers saved in SSHetu: id, label, address '
          '(user@host:port), group and tags. Never includes passwords, keys '
          'or notes. Filter with "query" (matches label, address and tags) '
          'or an exact "tag".',
      inputSchema: _schema({
        'query': _string('Case-insensitive text to match.'),
        'tag': _string('Only hosts with exactly this tag.'),
      }),
      handler: (args) async {
        final query = args.optionalString('query')?.trim().toLowerCase();
        final tag = args.optionalString('tag')?.trim().toLowerCase();
        final hosts = [
          for (final host in await backend.hosts())
            if ((query == null ||
                    query.isEmpty ||
                    host.label.toLowerCase().contains(query) ||
                    host.address.toLowerCase().contains(query) ||
                    host.tags.any((t) => t.toLowerCase().contains(query))) &&
                (tag == null ||
                    tag.isEmpty ||
                    host.tags.any((t) => t.toLowerCase() == tag)))
              host.toJson(),
        ];
        return McpToolResult.json({'hosts': hosts});
      },
    ),
    McpTool.read(
      name: 'list_sessions',
      title: 'List open sessions',
      description:
          'Lists the terminal sessions open in SSHetu (one per tab or pane): '
          'id, title, host, address, status (connecting, running, closed, '
          'failed) and which one is showing.',
      inputSchema: _schema({}),
      handler: (args) async => McpToolResult.json({
        'sessions': [for (final s in backend.sessions()) s.toJson()],
      }),
    ),
    McpTool.read(
      name: 'read_terminal',
      title: 'Read terminal output',
      description:
          'Returns the last "lines" lines of a session\'s terminal as plain '
          'text (default 100, at most 2000). This is screen-scraping: it is '
          'what the terminal shows, including prompts and whatever a '
          'full-screen program drew, not a structured command result.',
      inputSchema: _schema(
        {
          'session_id': _string('From list_sessions.'),
          'lines': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 2000,
            'default': 100,
            'description': 'How many lines from the bottom.',
          },
        },
        required: ['session_id'],
      ),
      auditTarget: (args) => args.values['session_id'] as String?,
      handler: (args) async {
        final session = sessionFor(args);
        final lines = args.optionalInt(
          'lines',
          fallback: 100,
          min: 1,
          max: 2000,
        );
        return McpToolResult(backend.terminalTail(session.id, lines));
      },
    ),
    McpTool.read(
      name: 'server_info',
      title: 'Server stats',
      description:
          'CPU, memory, load, uptime, disks and process count for the server '
          'behind a connected session — the numbers SSHetu\'s server panel '
          'shows, read over the session\'s own connection.',
      inputSchema: _schema(
        {'session_id': _string('A connected session, from list_sessions.')},
        required: ['session_id'],
      ),
      auditTarget: (args) => args.values['session_id'] as String?,
      handler: (args) async {
        final session = liveSessionFor(args);
        return McpToolResult.json(await backend.serverInfo(session.id));
      },
    ),
    McpTool.read(
      name: 'list_tunnels',
      title: 'List tunnels',
      description:
          'Lists saved port forwards with their live state (stopped, '
          'starting, running, failed), bound port and open connections.',
      inputSchema: _schema({}),
      handler: (args) async => McpToolResult.json({
        'tunnels': [for (final t in await backend.tunnels()) t.toJson()],
      }),
    ),
    McpTool.read(
      name: 'list_snippets',
      title: 'List snippets',
      description:
          'Lists saved snippets: id, label, description, tags, body, and the '
          '{{variables}} run_snippet needs values for. host, user, port, '
          'label, date and time are filled in automatically.',
      inputSchema: _schema({}),
      handler: (args) async => McpToolResult.json({
        'snippets': [
          for (final snippet in await backend.snippets())
            {
              'id': snippet.id,
              'label': snippet.label,
              'description': ?snippet.description,
              'tags': snippet.tags,
              'body': snippet.body,
              'variables': [
                for (final variable in SnippetTemplate.parse(
                  snippet.body,
                ).variables)
                  if (!SnippetBuiltins.all.contains(variable.name))
                    SnippetVariableSummary(
                      variable.name,
                      defaultValue: variable.defaultValue,
                    ).toJson(),
              ],
            },
        ],
      }),
    ),

    // ----------------------------------------------------------------- act
    McpTool.act(
      name: 'run_command',
      title: 'Run a command in a session',
      description:
          'Types "command" into an open session and presses Enter (each line '
          'of a multi-line command is entered in turn). Asks the user to '
          'approve first. Then waits up to "wait_seconds" (default 3, max 30) '
          'for output to settle and returns what the terminal received as '
          'plain text — screen-scraped, with no exit status; a long-running '
          'command may still be going. Use read_terminal to look again.',
      inputSchema: _schema(
        {
          'session_id': _string('A connected session, from list_sessions.'),
          'command': _string('The shell command to type.'),
          'wait_seconds': _waitSchema(3),
        },
        required: ['session_id', 'command'],
      ),
      plan: (args) async {
        final session = liveSessionFor(args);
        final command = limited(args, 'command', 16 * 1024);
        final wait = waitFrom(args, fallback: 3);
        return ActPlan(
          target: session.describe,
          details: [
            ApprovalDetail(ApprovalDetailKind.command, visibleText(command)),
          ],
          rememberScope: session.id,
          run: () async => outputResult(
            await backend.typeLines(session.id, command, wait),
            wait,
          ),
        );
      },
    ),
    McpTool.act(
      name: 'send_input',
      title: 'Send keystrokes to a session',
      description:
          'Sends "data" to a session exactly as given, with no Enter added — '
          'for answering a prompt, or control keys such as "\\u0003" '
          '(Ctrl-C) or "\\u001b" (Esc). Asks the user to approve first. '
          'Then returns output received within "wait_seconds" (default 1).',
      inputSchema: _schema(
        {
          'session_id': _string('A connected session, from list_sessions.'),
          'data': _string('The characters to send.'),
          'wait_seconds': _waitSchema(1),
        },
        required: ['session_id', 'data'],
      ),
      plan: (args) async {
        final session = liveSessionFor(args);
        final data = limited(args, 'data', 4 * 1024);
        final wait = waitFrom(args, fallback: 1);
        return ActPlan(
          target: session.describe,
          details: [
            ApprovalDetail(ApprovalDetailKind.input, visibleText(data)),
          ],
          rememberScope: session.id,
          run: () async =>
              outputResult(await backend.sendRaw(session.id, data, wait), wait),
        );
      },
    ),
    McpTool.act(
      name: 'open_session',
      title: 'Open a session to a saved host',
      description:
          'Opens a new terminal tab to a saved host, through SSHetu\'s normal '
          'connect flow — the user may be asked to trust a host key or enter '
          'a password there. Asks the user to approve first. Returns the new '
          'session.',
      inputSchema: _schema(
        {'host_id': _string('From list_hosts.')},
        required: ['host_id'],
      ),
      plan: (args) async {
        final id = args.requireString('host_id');
        final hosts = await backend.hosts();
        final host = hosts.where((h) => h.id == id).firstOrNull;
        if (host == null) {
          throw McpToolException(
            'No saved host with id "$id". Call list_hosts for the ids.',
          );
        }
        return ActPlan(
          target: '${host.label} — ${host.address}',
          details: [ApprovalDetail(ApprovalDetailKind.host, host.address)],
          run: () async =>
              McpToolResult.json((await backend.openSession(id)).toJson()),
        );
      },
    ),
    for (final start in [true, false])
      McpTool.act(
        name: start ? 'start_tunnel' : 'stop_tunnel',
        title: start ? 'Start a tunnel' : 'Stop a tunnel',
        description: start
            ? 'Starts a saved port forward, connecting to its host if needed '
                  '(the user may be asked for a host key or password). Asks '
                  'the user to approve first. Returns its new state.'
            : 'Stops a running port forward. Asks the user to approve first.',
        inputSchema: _schema(
          {'tunnel_id': _string('From list_tunnels.')},
          required: ['tunnel_id'],
        ),
        plan: (args) async {
          final id = args.requireString('tunnel_id');
          final tunnel = (await backend.tunnels())
              .where((t) => t.id == id)
              .firstOrNull;
          if (tunnel == null) {
            throw McpToolException(
              'No saved tunnel with id "$id". Call list_tunnels for the ids.',
            );
          }
          return ActPlan(
            target: tunnel.describe,
            details: [ApprovalDetail(ApprovalDetailKind.tunnel, tunnel.label)],
            run: () async => McpToolResult.json(
              (start
                      ? await backend.startTunnel(id)
                      : await backend.stopTunnel(id))
                  .toJson(),
            ),
          );
        },
      ),
    McpTool.act(
      name: 'run_snippet',
      title: 'Run a snippet in a session',
      description:
          'Fills in a saved snippet and runs it in an open session, line by '
          'line, the way SSHetu\'s Run does. Give values for its variables '
          'in "variables" (list_snippets names them; ones with a default may '
          'be left out). Asks the user to approve first, showing the exact '
          'text. Returns output received within "wait_seconds" (default 3), '
          'screen-scraped.',
      inputSchema: _schema(
        {
          'snippet_id': _string('From list_snippets.'),
          'session_id': _string('A connected session, from list_sessions.'),
          'variables': {
            'type': 'object',
            'additionalProperties': {'type': 'string'},
            'description': 'Variable name to value.',
          },
          'wait_seconds': _waitSchema(3),
        },
        required: ['snippet_id', 'session_id'],
      ),
      plan: (args) async {
        final snippetId = args.requireString('snippet_id');
        final session = liveSessionFor(args);
        final values = args.optionalStringMap('variables');
        final wait = waitFrom(args, fallback: 3);
        final snippet = (await backend.snippets())
            .where((s) => s.id == snippetId)
            .firstOrNull;
        if (snippet == null) {
          throw McpToolException(
            'No snippet with id "$snippetId". Call list_snippets for the ids.',
          );
        }
        final template = SnippetTemplate.parse(snippet.body);
        final builtins = SnippetBuiltins.values(
          host: session.hostname,
          user: session.username,
          port: session.port,
          label: session.title,
          now: clock(),
        );
        final missing = [
          for (final variable in template.userVariables(builtins))
            if (variable.defaultValue == null &&
                !values.containsKey(variable.name))
              variable.name,
        ];
        if (missing.isNotEmpty) {
          throw McpToolException(
            'Missing values for: ${missing.join(', ')}. Pass them in '
            '"variables".',
          );
        }
        final text = template.render(builtins: builtins, values: values);
        if (text.trim().isEmpty) {
          throw const McpToolException('The snippet is empty once filled in.');
        }
        return ActPlan(
          target: session.describe,
          details: [
            ApprovalDetail(ApprovalDetailKind.snippet, snippet.label),
            ApprovalDetail(ApprovalDetailKind.command, visibleText(text)),
          ],
          // Per snippet as well as per session: approving "restart nginx"
          // for a while says nothing about another snippet.
          rememberScope: '${session.id}/${snippet.id}',
          run: () async => outputResult(
            await backend.typeLines(session.id, text, wait),
            wait,
          ),
        );
      },
    ),
    McpTool.act(
      name: 'sftp_download',
      title: 'Download a file',
      description:
          'Copies a file from the server behind a session to this computer '
          'over SFTP. "local_path" must be absolute; an existing local file '
          'is only replaced with "overwrite": true. Asks the user to approve '
          'first, showing both paths.',
      inputSchema: _schema(
        {
          'session_id': _string('A connected session, from list_sessions.'),
          'remote_path': _string('The file on the server; ~ is its home.'),
          'local_path': _string('Absolute path on this computer.'),
          'overwrite': _bool('Replace an existing local file.'),
        },
        required: ['session_id', 'remote_path', 'local_path'],
      ),
      plan: (args) async {
        final session = liveSessionFor(args);
        final remote = args.requireString('remote_path');
        final local = localPathFrom(args);
        final overwrite = args.optionalBool('overwrite');
        return ActPlan(
          target: session.describe,
          details: [
            ApprovalDetail(ApprovalDetailKind.remotePath, visibleText(remote)),
            ApprovalDetail(ApprovalDetailKind.localPath, visibleText(local)),
            if (overwrite)
              const ApprovalDetail(ApprovalDetailKind.overwrite, ''),
          ],
          run: () async => McpToolResult.json(
            (await backend.download(
              sessionId: session.id,
              remotePath: remote,
              localPath: local,
              overwrite: overwrite,
            )).toJson(),
          ),
        );
      },
    ),
    McpTool.act(
      name: 'sftp_upload',
      title: 'Upload a file',
      description:
          'Copies a file from this computer to the server behind a session '
          'over SFTP. "local_path" must be absolute; an existing remote file '
          'is only replaced with "overwrite": true. Asks the user to approve '
          'first, showing both paths.',
      inputSchema: _schema(
        {
          'session_id': _string('A connected session, from list_sessions.'),
          'local_path': _string('Absolute path of the file on this computer.'),
          'remote_path': _string('Where to put it on the server; ~ is home.'),
          'overwrite': _bool('Replace an existing remote file.'),
        },
        required: ['session_id', 'local_path', 'remote_path'],
      ),
      plan: (args) async {
        final session = liveSessionFor(args);
        final local = localPathFrom(args);
        final remote = args.requireString('remote_path');
        final overwrite = args.optionalBool('overwrite');
        return ActPlan(
          target: session.describe,
          details: [
            ApprovalDetail(ApprovalDetailKind.localPath, visibleText(local)),
            ApprovalDetail(ApprovalDetailKind.remotePath, visibleText(remote)),
            if (overwrite)
              const ApprovalDetail(ApprovalDetailKind.overwrite, ''),
          ],
          run: () async => McpToolResult.json(
            (await backend.upload(
              sessionId: session.id,
              localPath: local,
              remotePath: remote,
              overwrite: overwrite,
            )).toJson(),
          ),
        );
      },
    ),
  ];
}

Map<String, Object?> _schema(
  Map<String, Object?> properties, {
  List<String> required = const [],
}) => {
  'type': 'object',
  'properties': properties,
  if (required.isNotEmpty) 'required': required,
  'additionalProperties': false,
};

Map<String, Object?> _string(String description) => {
  'type': 'string',
  'description': description,
};

Map<String, Object?> _bool(String description) => {
  'type': 'boolean',
  'default': false,
  'description': description,
};

Map<String, Object?> _waitSchema(int fallback) => {
  'type': 'integer',
  'minimum': 0,
  'maximum': 30,
  'default': fallback,
  'description': 'Seconds to wait for output to settle.',
};
