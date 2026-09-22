import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/snippets/domain/snippet_template.dart';

/// The placeholder syntax. The rule under every test here: a snippet must
/// never quietly rewrite a command, so anything that is not exactly a
/// placeholder comes out as it went in.
void main() {
  List<SnippetVariable> vars(String body) =>
      SnippetTemplate.parse(body).variables;

  String render(
    String body, {
    Map<String, String> builtins = const {},
    Map<String, String> values = const {},
  }) => SnippetTemplate.parse(body).render(builtins: builtins, values: values);

  group('parsing', () {
    test('plain text has no variables and renders unchanged', () {
      expect(vars('ls -la /var/log'), isEmpty);
      expect(render('ls -la /var/log'), 'ls -la /var/log');
    });

    test('a variable, with and without a default', () {
      expect(vars('cd {{dir}} && tail -f {{file:app.log}}'), const [
        SnippetVariable('dir'),
        SnippetVariable('file', defaultValue: 'app.log'),
      ]);
    });

    test('spaces inside the braces are allowed around the name', () {
      expect(vars('echo {{ name }}'), const [SnippetVariable('name')]);
    });

    test('a default keeps everything after the first colon verbatim', () {
      expect(vars('curl {{url:http://localhost:8080/a b}}'), const [
        SnippetVariable('url', defaultValue: 'http://localhost:8080/a b'),
      ]);
    });

    test('an empty default is a default, not no default', () {
      expect(vars('echo {{x:}}'), const [
        SnippetVariable('x', defaultValue: ''),
      ]);
    });

    test('a repeated variable is reported once, in first-seen order', () {
      expect(vars('cp {{src}} {{dst}} && ls {{src}} {{dst}}'), const [
        SnippetVariable('src'),
        SnippetVariable('dst'),
      ]);
    });

    test('a default on a later occurrence is still offered', () {
      expect(vars('mkdir {{dir}} && cd {{dir:/tmp/work}}'), const [
        SnippetVariable('dir', defaultValue: '/tmp/work'),
      ]);
    });

    test('the first default wins when two disagree', () {
      expect(vars('{{n:1}} {{n:2}}'), const [
        SnippetVariable('n', defaultValue: '1'),
      ]);
    });
  });

  group('escaping', () {
    test(r'\{{ is a literal {{ and starts no variable', () {
      expect(vars(r'echo \{{name}}'), isEmpty);
      expect(render(r'echo \{{name}}'), 'echo {{name}}');
    });

    test('an escaped and a real placeholder side by side', () {
      const body = r'echo \{{literal}} {{real}}';
      expect(vars(body), const [SnippetVariable('real')]);
      expect(render(body, values: {'real': 'x'}), 'echo {{literal}} x');
    });

    test('a backslash anywhere else is shell text', () {
      expect(render(r'printf "a\tb\n" \{ x \}'), r'printf "a\tb\n" \{ x \}');
    });
  });

  group('malformed braces are left as text', () {
    for (final body in [
      // Go templates, the classic collision.
      "docker inspect --format '{{.State.Status}}' web",
      "docker ps --format '{{ .Names }}'",
      'echo {{}}',
      'echo {{ }}',
      'echo {{two words}}',
      'echo {{1st}}',
      'echo {{unclosed',
      'echo }}',
      'echo {single}',
      '{{:nodefault}}',
      'echo {{split\nacross}}',
      r"awk '{print $1}'",
    ]) {
      test(body.replaceAll('\n', r'\n'), () {
        expect(vars(body), isEmpty);
        expect(render(body), body);
      });
    }

    test('an opening inside another placeholder restarts it', () {
      // `{{a {{b}}` is text followed by `{{b}}`, not a variable "a {{b".
      expect(vars('{{a {{b}}'), const [SnippetVariable('b')]);
      expect(render('{{a {{b}}', values: {'b': 'B'}), '{{a B');
    });

    test('a third closing brace is text', () {
      expect(render('{{x}}}', values: {'x': 'X'}), 'X}');
    });
  });

  group('rendering', () {
    test('values fill variables; missing ones fall back to the default', () {
      expect(
        render('ssh {{u:root}}@{{h}}', values: {'h': 'box'}),
        'ssh root@box',
      );
    });

    test('a variable with neither value nor default becomes empty', () {
      expect(render('echo [{{x}}]'), 'echo []');
    });

    test('every occurrence of a repeated variable gets the same value', () {
      expect(render('{{a}}-{{a}}-{{a}}', values: {'a': 'z'}), 'z-z-z');
    });

    test('a built-in wins over a typed value of the same name', () {
      expect(
        render(
          '{{host}}',
          builtins: {'host': 'real.example'},
          values: {'host': 'typed'},
        ),
        'real.example',
      );
    });

    test('values are inserted literally, never re-parsed', () {
      expect(render('echo {{a}}', values: {'a': '{{b}}'}), 'echo {{b}}');
    });
  });

  group('built-ins', () {
    final builtins = SnippetBuiltins.values(
      host: 'db.example.com',
      user: 'deploy',
      port: 2222,
      label: 'prod db',
      now: DateTime(2026, 3, 7, 9, 5, 4),
    );

    test('come from the session, with a padded date and time', () {
      expect(builtins, {
        'host': 'db.example.com',
        'user': 'deploy',
        'port': '2222',
        'label': 'prod db',
        'date': '2026-03-07',
        'time': '09:05:04',
      });
    });

    test('are not asked for', () {
      final template = SnippetTemplate.parse(
        'ssh {{user}}@{{host}} -p {{port}} # {{label}} {{date}} {{time}}',
      );
      expect(template.userVariables(builtins), isEmpty);
      expect(template.needsInput(builtins), isFalse);
      expect(
        template.render(builtins: builtins),
        'ssh deploy@db.example.com -p 2222 # prod db 2026-03-07 09:05:04',
      );
    });

    test('an unknown built-in is an ordinary question', () {
      final template = SnippetTemplate.parse('ping {{hostname}} {{host}}');
      expect(template.userVariables(builtins), const [
        SnippetVariable('hostname'),
      ]);
    });

    test('a built-in the context lacks is asked for like any other', () {
      final template = SnippetTemplate.parse('echo {{host:localhost}}');
      expect(template.userVariables(const {}), const [
        SnippetVariable('host', defaultValue: 'localhost'),
      ]);
    });

    test('names are case-sensitive, so {{HOST}} is not {{host}}', () {
      final template = SnippetTemplate.parse('{{HOST}}');
      expect(template.userVariables(builtins), const [SnippetVariable('HOST')]);
    });
  });

  test('the syntax examples shown to the user parse as they claim', () {
    expect(vars(SnippetSyntax.example), const [SnippetVariable('name')]);
    expect(vars(SnippetSyntax.defaultExample), const [
      SnippetVariable('name', defaultValue: 'default'),
    ]);
    expect(
      vars(SnippetSyntax.builtinList).map((v) => v.name),
      SnippetBuiltins.all,
    );
  });
}
