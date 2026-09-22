/// `{{placeholders}}` in a snippet body: parsing, and filling them in.
///
/// Pure on purpose — no Flutter, no terminal — so every rule here is pinned
/// by `test/features/snippets/domain/snippet_template_test.dart`.
///
/// The syntax:
///
/// - `{{name}}` — a value asked for when the snippet is used.
/// - `{{name:default}}` — the same, with the field prefilled. The default is
///   everything after the first `:` up to the closing braces, kept verbatim,
///   so `{{url:http://localhost:8080}}` works.
/// - `\{{` — a literal `{{`. Only that exact sequence is an escape; a
///   backslash anywhere else is shell text and is left alone.
/// - Names are a letter or `_`, then letters, digits, `_`, `-` or `.`, with
///   optional spaces inside the braces (`{{ name }}`).
///
/// **Anything that does not fit that shape is left as text.** Shell and the
/// tools people drive from it use braces for their own purposes — Go
/// templates in `docker inspect --format '{{.State.Status}}'`, Jinja,
/// Mustache, brace expansion — and the worst thing a snippet can do is
/// quietly rewrite a command. So `{{.State}}`, `{{ }}`, `{{a b}}`, an
/// unclosed `{{name` and a placeholder broken across lines all come out
/// exactly as they went in.
library;

/// The placeholders filled from the session a snippet runs in, rather than
/// asked for.
abstract final class SnippetBuiltins {
  static const String host = 'host';
  static const String user = 'user';
  static const String port = 'port';
  static const String label = 'label';
  static const String date = 'date';
  static const String time = 'time';

  static const List<String> all = [host, user, port, label, date, time];

  /// The values for one session at one moment.
  ///
  /// [date] is `YYYY-MM-DD` and [time] `HH:MM:SS`, both 24-hour local time:
  /// the forms that sort as text and that `date +%F` / `date +%T` print, so
  /// a filename built from them lines up with one the shell would build.
  static Map<String, String> values({
    required String host,
    required String user,
    required int port,
    required String label,
    required DateTime now,
  }) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = now.toLocal();
    return {
      SnippetBuiltins.host: host,
      SnippetBuiltins.user: user,
      SnippetBuiltins.port: '$port',
      SnippetBuiltins.label: label,
      SnippetBuiltins.date:
          '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
          '${two(local.day)}',
      SnippetBuiltins.time:
          '${two(local.hour)}:${two(local.minute)}:${two(local.second)}',
    };
  }
}

/// Examples of the syntax, for the strings that explain it.
///
/// Kept out of the ARB file because `{` is ICU's placeholder syntax there:
/// the prose is translated, and these are passed in as they are.
abstract final class SnippetSyntax {
  static const String example = '{{name}}';
  static const String defaultExample = '{{name:default}}';
  static const String bodyExample = 'sudo systemctl restart {{service:nginx}}';

  /// Every built-in, spelled as it is typed.
  static String get builtinList =>
      SnippetBuiltins.all.map((name) => '{{$name}}').join(', ');
}

/// One variable a template uses, reported once however often it appears.
class SnippetVariable {
  const SnippetVariable(this.name, {this.defaultValue});

  final String name;

  /// The first default written for this name, if any occurrence had one.
  final String? defaultValue;

  @override
  bool operator ==(Object other) =>
      other is SnippetVariable &&
      other.name == name &&
      other.defaultValue == defaultValue;

  @override
  int get hashCode => Object.hash(name, defaultValue);

  @override
  String toString() => 'SnippetVariable($name, $defaultValue)';
}

/// A piece of a parsed template.
sealed class TemplateSegment {
  const TemplateSegment();
}

/// Text copied through as it stands.
class LiteralSegment extends TemplateSegment {
  const LiteralSegment(this.text);

  final String text;
}

/// A `{{name}}` or `{{name:default}}`.
class VariableSegment extends TemplateSegment {
  const VariableSegment(this.name, {this.defaultValue});

  final String name;
  final String? defaultValue;
}

/// A snippet body, parsed.
class SnippetTemplate {
  SnippetTemplate._(this.segments);

  /// Parses [body]. Never throws: anything malformed is literal text.
  factory SnippetTemplate.parse(String body) {
    final segments = <TemplateSegment>[];
    final literal = StringBuffer();

    void flushLiteral() {
      if (literal.isEmpty) return;
      segments.add(LiteralSegment(literal.toString()));
      literal.clear();
    }

    var i = 0;
    while (i < body.length) {
      if (body.startsWith(r'\{{', i)) {
        literal.write('{{');
        i += 3;
        continue;
      }
      if (body.startsWith('{{', i)) {
        final placeholder = _placeholderAt(body, i);
        if (placeholder != null) {
          flushLiteral();
          segments.add(placeholder.segment);
          i = placeholder.end;
          continue;
        }
      }
      literal.write(body[i]);
      i++;
    }
    flushLiteral();
    return SnippetTemplate._(List.unmodifiable(segments));
  }

  final List<TemplateSegment> segments;

  /// Every variable, once each, in the order they first appear.
  List<SnippetVariable> get variables {
    final order = <String>[];
    final defaults = <String, String?>{};
    for (final segment in segments) {
      if (segment is! VariableSegment) continue;
      if (!defaults.containsKey(segment.name)) {
        order.add(segment.name);
        defaults[segment.name] = segment.defaultValue;
      } else if (defaults[segment.name] == null) {
        // `{{dir}} … {{dir:/tmp}}` — the default is still worth offering.
        defaults[segment.name] = segment.defaultValue;
      }
    }
    return [
      for (final name in order)
        SnippetVariable(name, defaultValue: defaults[name]),
    ];
  }

  /// The variables the user has to be asked for, given [builtins].
  ///
  /// A built-in name only counts as filled when [builtins] actually has a
  /// value for it; otherwise — and for every name that is not a built-in at
  /// all, `{{hostname}}` included — it is an ordinary question.
  List<SnippetVariable> userVariables(Map<String, String> builtins) => [
    for (final variable in variables)
      if (!builtins.containsKey(variable.name)) variable,
  ];

  /// Whether [render] needs anything from the user.
  bool needsInput(Map<String, String> builtins) =>
      userVariables(builtins).isNotEmpty;

  /// Fills every placeholder: [builtins] first, then [values], then the
  /// placeholder's own default, then nothing.
  ///
  /// A built-in wins over a user value of the same name because a session's
  /// address is a fact, not a preference.
  String render({
    Map<String, String> builtins = const {},
    Map<String, String> values = const {},
  }) {
    final out = StringBuffer();
    for (final segment in segments) {
      switch (segment) {
        case LiteralSegment(:final text):
          out.write(text);
        case VariableSegment(:final name, :final defaultValue):
          out.write(builtins[name] ?? values[name] ?? defaultValue ?? '');
      }
    }
    return out.toString();
  }

  static final _name = RegExp(r'^[A-Za-z_][A-Za-z0-9_.\-]*$');

  /// The placeholder opening at [start], or null when what is there is not
  /// one and should stay text.
  static ({VariableSegment segment, int end})? _placeholderAt(
    String body,
    int start,
  ) {
    final close = body.indexOf('}}', start + 2);
    if (close < 0) return null;
    final inner = body.substring(start + 2, close);
    // A placeholder never spans lines, and never contains another opening:
    // `{{a {{b}}` is text followed by `{{b}}`, not a variable called "a {{b".
    if (inner.contains('\n') || inner.contains('\r')) return null;
    if (inner.contains('{{')) return null;

    final colon = inner.indexOf(':');
    final rawName = colon < 0 ? inner : inner.substring(0, colon);
    final name = rawName.trim();
    if (!_name.hasMatch(name)) return null;

    final defaultValue = colon < 0 ? null : inner.substring(colon + 1);
    return (
      segment: VariableSegment(name, defaultValue: defaultValue),
      end: close + 2,
    );
  }
}
