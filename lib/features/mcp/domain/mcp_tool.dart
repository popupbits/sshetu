import 'dart:convert';

import 'approval.dart';

/// Whether a tool only looks, or changes something.
///
/// The server enforces the difference: an [McpToolKind.act] tool has no way
/// to run except through the approval gate, whatever the client claims.
enum McpToolKind { read, act }

/// What a tool call returns to the client.
class McpToolResult {
  const McpToolResult(this.text, {this.structured, this.isError = false});

  /// [value] as indented JSON, and as structured content beside it.
  factory McpToolResult.json(Map<String, Object?> value) => McpToolResult(
    const JsonEncoder.withIndent('  ').convert(value),
    structured: value,
  );

  /// A tool execution error: the model reads [message] and can correct
  /// itself, which a protocol error would not let it do.
  const McpToolResult.error(String message) : this(message, isError: true);

  final String text;
  final Map<String, Object?>? structured;
  final bool isError;

  int get sizeInBytes => utf8.encode(text).length;

  Map<String, Object?> toJson() => {
    'content': [
      {'type': 'text', 'text': text},
    ],
    'structuredContent': ?structured,
    if (isError) 'isError': true,
  };
}

/// A call that cannot go ahead, with the reason the client is told.
class McpToolException implements Exception {
  const McpToolException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The arguments of one call, read with the checks every tool needs.
class ToolArgs {
  const ToolArgs(this.values);

  final Map<String, Object?> values;

  String requireString(String name) {
    final value = values[name];
    if (value is! String || value.isEmpty) {
      throw McpToolException('"$name" is required and must be a string.');
    }
    return value;
  }

  String? optionalString(String name) {
    final value = values[name];
    if (value == null) return null;
    if (value is! String) {
      throw McpToolException('"$name" must be a string.');
    }
    return value;
  }

  int optionalInt(
    String name, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final value = values[name];
    if (value == null) return fallback;
    // JSON has one number type; 5.0 is a fine way to say 5.
    final number = value is num && value == value.roundToDouble()
        ? value.toInt()
        : null;
    if (number == null) {
      throw McpToolException('"$name" must be a whole number.');
    }
    if (number < min || number > max) {
      throw McpToolException('"$name" must be between $min and $max.');
    }
    return number;
  }

  bool optionalBool(String name, {bool fallback = false}) {
    final value = values[name];
    if (value == null) return fallback;
    if (value is! bool) {
      throw McpToolException('"$name" must be true or false.');
    }
    return value;
  }

  Map<String, String> optionalStringMap(String name) {
    final value = values[name];
    if (value == null) return const {};
    if (value is! Map) throw McpToolException('"$name" must be an object.');
    final out = <String, String>{};
    value.forEach((key, entry) {
      if (key is! String || entry is! String) {
        throw McpToolException('"$name" must map names to strings.');
      }
      out[key] = entry;
    });
    return out;
  }
}

/// What an act tool would do, shown to the user before it does it.
class ActPlan {
  const ActPlan({
    required this.target,
    required this.run,
    this.details = const [],
    this.rememberScope,
  });

  /// The exact host, session or tunnel acted on, as the dialog names it.
  final String target;
  final List<ApprovalDetail> details;

  /// Set when "approve similar" may be offered: the scope a grant covers —
  /// the session id. Null for calls that must be approved every time.
  final String? rememberScope;

  /// Does it. Called only after approval.
  final Future<McpToolResult> Function() run;
}

/// One tool: its advertised shape and its handler.
class McpTool {
  /// A tool that only reads. Runs without asking.
  const McpTool.read({
    required this.name,
    required this.title,
    required this.description,
    required this.inputSchema,
    required Future<McpToolResult> Function(ToolArgs args) handler,
    this.auditTarget,
  }) : kind = McpToolKind.read,
       _read = handler,
       _planner = null;

  /// A tool that changes something. [plan] describes the call and returns
  /// how to run it; the dispatcher asks the user in between.
  const McpTool.act({
    required this.name,
    required this.title,
    required this.description,
    required this.inputSchema,
    required Future<ActPlan> Function(ToolArgs args) plan,
  }) : kind = McpToolKind.act,
       _read = null,
       _planner = plan,
       auditTarget = null;

  final String name;
  final String title;
  final String description;
  final Map<String, Object?> inputSchema;
  final McpToolKind kind;
  final Future<McpToolResult> Function(ToolArgs args)? _read;
  final Future<ActPlan> Function(ToolArgs args)? _planner;

  /// What the activity log names as a read call's target.
  final String? Function(ToolArgs args)? auditTarget;

  Future<McpToolResult> read(ToolArgs args) {
    final handler = _read;
    if (handler == null) throw StateError('$name is not a read tool');
    return handler(args);
  }

  Future<ActPlan> plan(ToolArgs args) {
    final handler = _planner;
    if (handler == null) throw StateError('$name is not an act tool');
    return handler(args);
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': inputSchema,
    'annotations': {
      'title': title,
      'readOnlyHint': kind == McpToolKind.read,
      'destructiveHint': kind == McpToolKind.act,
      'openWorldHint': true,
    },
  };
}
