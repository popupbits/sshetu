import 'package:xterm2/xterm.dart';

import '../../core/terminal/paste_sanitizer.dart';
import '../../core/terminal/terminal_session.dart';
import 'domain/snippet_template.dart';

/// What using a snippet does once its text is ready.
enum SnippetAction {
  /// Types it at the prompt and stops — nothing is run.
  insert,

  /// Types it and presses Enter, line by line.
  run,
}

/// A session a snippet can be typed into.
///
/// The picker and the send path talk to this rather than to
/// [TerminalSession], so a test can hand them a bare [Terminal] and read back
/// exactly what would have gone down the wire, with no SSH connection behind
/// it.
class SnippetTarget {
  const SnippetTarget({
    required this.id,
    required this.title,
    required this.terminal,
    required this.isLive,
    required this.host,
    required this.user,
    required this.port,
  });

  /// Everything a snippet needs from an open tab.
  factory SnippetTarget.fromSession(TerminalSession session) => SnippetTarget(
    id: session.id,
    title: session.title,
    terminal: session.terminal,
    isLive: session.isLive,
    host: session.target.hostname,
    user: session.target.username,
    port: session.target.port,
  );

  final String id;

  /// The tab's name — the host's label.
  final String title;

  /// The terminal whose output goes to the remote shell.
  final Terminal terminal;

  /// Whether typing into it reaches anything.
  final bool isLive;

  final String host;
  final String user;
  final int port;

  /// `user@host:port`, for telling apart two tabs with the same label.
  String get address => '$user@$host:$port';

  /// The built-in placeholder values for this session at [now].
  Map<String, String> builtins(DateTime now) => SnippetBuiltins.values(
    host: host,
    user: user,
    port: port,
    label: title,
    now: now,
  );
}

/// How one delivery went.
enum SnippetDeliveryResult {
  /// Typed into the session.
  sent,

  /// The session is not connected, so nothing was typed.
  notLive,

  /// Nothing was left once control characters were removed.
  empty,

  /// A multi-line insert into a program that has not turned on bracketed
  /// paste. Sending it would run every line but the last, which is the one
  /// thing Insert promises not to do — so nothing was typed.
  multilineNeedsBracketedPaste,
}

/// Types [rendered] into [target].
///
/// **Sanitised first**, through the same [sanitizePaste] the clipboard uses:
/// a snippet is text the user chose, but it may have been pasted into the
/// editor from anywhere, and an escape sequence in a saved command would
/// replay on every use. It does *not* go through the paste confirmation —
/// choosing Run is already the user saying "run this".
///
/// - **Insert** trims trailing line breaks (a body saved with a final newline
///   must not press Enter) and sends the rest through `Terminal.paste`. When
///   the remote program has turned bracketed paste on, a multi-line insert
///   arrives as one paste and runs nothing. When it has not, a line break is
///   an Enter, so a multi-line insert is refused rather than half-executed.
/// - **Run** sends each line, then Enter. Each line goes through
///   `Terminal.paste` too, so a line containing a tab reaches the shell as a
///   tab rather than triggering completion part-way through.
SnippetDeliveryResult deliverSnippet(
  SnippetTarget target,
  String rendered,
  SnippetAction action,
) {
  if (!target.isLive) return SnippetDeliveryResult.notLive;
  final clean = sanitizePaste(rendered);
  final terminal = target.terminal;

  switch (action) {
    case SnippetAction.insert:
      final text = clean.text.replaceFirst(RegExp(r'[\r\n]+$'), '');
      if (text.isEmpty) return SnippetDeliveryResult.empty;
      final multiline = text.contains('\n') || text.contains('\r');
      if (multiline && !terminal.bracketedPasteMode) {
        return SnippetDeliveryResult.multilineNeedsBracketedPaste;
      }
      terminal.paste(text);
      return SnippetDeliveryResult.sent;

    case SnippetAction.run:
      final lines = clean.lines;
      if (lines.every((line) => line.isEmpty)) {
        return SnippetDeliveryResult.empty;
      }
      for (final line in lines) {
        if (line.isNotEmpty) terminal.paste(line);
        terminal.textInput('\r');
      }
      return SnippetDeliveryResult.sent;
  }
}

/// The outcome of running one snippet in several sessions.
class SnippetBroadcastSummary {
  const SnippetBroadcastSummary({required this.sent, required this.skipped});

  /// Tabs it was typed into.
  final List<SnippetTarget> sent;

  /// Tabs it was not, because they were not connected or the text was empty.
  final List<SnippetTarget> skipped;
}

/// Renders [template] per target — each gets its own `{{host}}` — and
/// delivers it with [action].
///
/// [values] are the answers to the user variables, asked once for all of
/// them: the question was about the command, not about any one server.
SnippetBroadcastSummary deliverToMany(
  SnippetTemplate template,
  List<SnippetTarget> targets,
  SnippetAction action, {
  Map<String, String> values = const {},
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final sent = <SnippetTarget>[];
  final skipped = <SnippetTarget>[];
  for (final target in targets) {
    final text = template.render(builtins: target.builtins(at), values: values);
    final result = deliverSnippet(target, text, action);
    (result == SnippetDeliveryResult.sent ? sent : skipped).add(target);
  }
  return SnippetBroadcastSummary(sent: sent, skipped: skipped);
}
