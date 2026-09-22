import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/snippets/domain/snippet_template.dart';
import 'package:sshetu/features/snippets/snippet_delivery.dart';
import 'package:xterm2/xterm.dart';

/// What actually reaches the remote shell when a snippet is used. The
/// terminal here has no connection behind it; its output — exactly what the
/// session would write to the SSH channel — is captured instead.
void main() {
  ({SnippetTarget target, List<String> sent}) fake({
    String id = 's1',
    bool live = true,
    bool bracketed = false,
    String host = 'web.example.com',
  }) {
    final terminal = Terminal();
    final sent = <String>[];
    terminal.onOutput = sent.add;
    // What bash and zsh send to turn bracketed paste on.
    if (bracketed) terminal.write('\x1b[?2004h');
    return (
      target: SnippetTarget(
        id: id,
        title: id,
        terminal: terminal,
        isLive: live,
        host: host,
        user: 'deploy',
        port: 22,
      ),
      sent: sent,
    );
  }

  group('insert', () {
    test('types the text and presses nothing', () {
      final f = fake();
      final result = deliverSnippet(f.target, 'ls -la', SnippetAction.insert);
      expect(result, SnippetDeliveryResult.sent);
      expect(f.sent.join(), 'ls -la');
    });

    test('drops a trailing newline, which would press Enter', () {
      final f = fake();
      deliverSnippet(f.target, 'ls -la\n', SnippetAction.insert);
      expect(f.sent.join(), 'ls -la');
    });

    test('a multi-line insert goes as one bracketed paste', () {
      final f = fake(bracketed: true);
      final result = deliverSnippet(
        f.target,
        'echo one\necho two',
        SnippetAction.insert,
      );
      expect(result, SnippetDeliveryResult.sent);
      expect(f.sent.join(), '\x1b[200~echo one\necho two\x1b[201~');
    });

    test('a multi-line insert without bracketed paste is refused', () {
      // Every line but the last would run as it arrived.
      final f = fake();
      final result = deliverSnippet(
        f.target,
        'echo one\necho two',
        SnippetAction.insert,
      );
      expect(result, SnippetDeliveryResult.multilineNeedsBracketedPaste);
      expect(f.sent, isEmpty);
    });
  });

  group('run', () {
    test('types the line and then Enter', () {
      final f = fake();
      deliverSnippet(f.target, 'uptime', SnippetAction.run);
      expect(f.sent.join(), 'uptime\r');
    });

    test('several lines go one at a time, each followed by Enter', () {
      final f = fake();
      deliverSnippet(f.target, 'cd /tmp\r\nls\n', SnippetAction.run);
      expect(f.sent, ['cd /tmp', '\r', 'ls', '\r']);
    });

    test('with bracketed paste, each line is pasted then entered', () {
      final f = fake(bracketed: true);
      deliverSnippet(f.target, 'a\nb', SnippetAction.run);
      expect(f.sent.join(), '\x1b[200~a\x1b[201~\r\x1b[200~b\x1b[201~\r');
    });
  });

  group('sanitising', () {
    test('escape sequences and hidden characters never reach the shell', () {
      final f = fake();
      deliverSnippet(
        f.target,
        'echo \u{202E}evil\x1b[31m red\x1b]0;title\x07',
        SnippetAction.run,
      );
      expect(f.sent.join(), 'echo evil red\r');
    });

    test('a smuggled end-of-paste cannot break out of bracketed paste', () {
      final f = fake(bracketed: true);
      deliverSnippet(
        f.target,
        'echo safe\x1b[201~rm -rf ~\necho after',
        SnippetAction.insert,
      );
      expect(f.sent.join(), '\x1b[200~echo saferm -rf ~\necho after\x1b[201~');
    });

    test('text that is nothing but control bytes sends nothing', () {
      final f = fake();
      expect(
        deliverSnippet(f.target, '\x1b[2J\x07', SnippetAction.run),
        SnippetDeliveryResult.empty,
      );
      expect(f.sent, isEmpty);
    });
  });

  test('a session that is not connected is typed into by nobody', () {
    final f = fake(live: false);
    expect(
      deliverSnippet(f.target, 'uptime', SnippetAction.run),
      SnippetDeliveryResult.notLive,
    );
    expect(f.sent, isEmpty);
  });

  group('run on several sessions', () {
    test('each session gets its own built-ins and the shared answers', () {
      final a = fake(id: 'a', host: 'a.example');
      final b = fake(id: 'b', host: 'b.example');
      final template = SnippetTemplate.parse('echo {{host}} {{msg}}');

      final summary = deliverToMany(
        template,
        [a.target, b.target],
        SnippetAction.run,
        values: {'msg': 'hi'},
        now: DateTime(2026),
      );

      expect(a.sent.join(), 'echo a.example hi\r');
      expect(b.sent.join(), 'echo b.example hi\r');
      expect(summary.sent.map((t) => t.id), ['a', 'b']);
      expect(summary.skipped, isEmpty);
    });

    test('a disconnected tab is skipped and reported, not typed into', () {
      final a = fake(id: 'a');
      final b = fake(id: 'b', live: false);

      final summary = deliverToMany(SnippetTemplate.parse('uptime'), [
        a.target,
        b.target,
      ], SnippetAction.run);

      expect(a.sent.join(), 'uptime\r');
      expect(b.sent, isEmpty);
      expect(summary.sent.map((t) => t.id), ['a']);
      expect(summary.skipped.map((t) => t.id), ['b']);
    });
  });
}
