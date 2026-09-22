import 'package:material_ui/material_ui.dart';

/// [text] on one line, with the characters at [highlights] emphasised.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    required this.highlights,
    this.style,
    super.key,
  });

  final String text;
  final List<int> highlights;
  final TextStyle? style;

  /// The runs of [text], each marked as matched or not — split out so a test
  /// can check the highlighting without reading spans off a render object.
  static List<(String, bool)> runs(String text, List<int> highlights) {
    final marked = highlights.toSet();
    final runs = <(String, bool)>[];
    final buffer = StringBuffer();
    bool? current;
    for (var i = 0; i < text.length; i++) {
      final hit = marked.contains(i);
      if (current != null && hit != current) {
        runs.add((buffer.toString(), current));
        buffer.clear();
      }
      current = hit;
      buffer.write(text[i]);
    }
    if (current != null) runs.add((buffer.toString(), current));
    return runs;
  }

  @override
  Widget build(BuildContext context) {
    final emphasis = TextStyle(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (run, hit) in runs(text, highlights))
            TextSpan(text: run, style: hit ? emphasis : null),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
