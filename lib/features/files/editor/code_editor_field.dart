import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';

/// A plain monospace text area with line numbers, for editing config files.
///
/// Lines do not wrap: a wrapped line would put the next line number beside
/// the wrong text, and config files are read by column. The text area is as
/// wide as its longest line (measured from the monospace advance, not laid
/// out twice) and scrolls sideways when that is wider than the view.
///
/// No syntax highlighting — a colouring package for a feature whose job is
/// "fix one line of nginx.conf" would weigh more than the feature.
class CodeEditorField extends StatefulWidget {
  const CodeEditorField({
    required this.controller,
    this.readOnly = false,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final bool readOnly;
  final FocusNode? focusNode;

  static const fieldKey = ValueKey('code-editor-field');

  @override
  State<CodeEditorField> createState() => _CodeEditorFieldState();
}

class _CodeEditorFieldState extends State<CodeEditorField> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  static const _tabColumns = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = Mono.apply(theme.textTheme.bodyMedium)
        .copyWith(color: scheme.onSurface, height: 1.4);
    // Forced, so the gutter's lines and the field's lines are the same height
    // whatever glyph a line happens to contain — the one thing that keeps a
    // number beside its line.
    final strut = StrutStyle.fromTextStyle(style, forceStrutHeight: true);
    final charWidth = _advance(style, context);

    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final text = widget.controller.text;
          final (lines, longest) = _measure(text);
          final digits = math.max(2, '$lines'.length);
          final gutterWidth = digits * charWidth + Spacing.md * 2;
          final contentWidth = longest * charWidth + Spacing.xxl;
          final available = math.max(
            0.0,
            constraints.maxWidth - gutterWidth - BorderWidths.hairline,
          );

          return Scrollbar(
            controller: _vertical,
            child: SingleChildScrollView(
              controller: _vertical,
              child: GestureDetector(
                // A tap below the last line still means "type here".
                behavior: HitTestBehavior.translucent,
                onTap: _focus.requestFocus,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  // The gutter's background and rule are painted full
                  // height behind the row, so they reach the bottom of the
                  // view on a short file without measuring the text twice.
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: gutterWidth,
                        child: ColoredBox(color: scheme.surfaceContainerLow),
                      ),
                      Positioned(
                        left: gutterWidth,
                        top: 0,
                        bottom: 0,
                        width: BorderWidths.hairline,
                        child: ColoredBox(color: scheme.outlineVariant),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: gutterWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.sm,
                            ),
                            child: Text(
                              List.generate(
                                lines,
                                (i) => '${i + 1}',
                              ).join('\n'),
                              textAlign: TextAlign.right,
                              strutStyle: strut,
                              style: style.copyWith(color: scheme.outline),
                            ),
                          ),
                          const SizedBox(width: BorderWidths.hairline),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _horizontal,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: math.max(available, contentWidth),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.md,
                                    vertical: Spacing.sm,
                                  ),
                                  child: TextField(
                                    key: CodeEditorField.fieldKey,
                                    controller: widget.controller,
                                    focusNode: _focus,
                                    readOnly: widget.readOnly,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    smartDashesType: SmartDashesType.disabled,
                                    smartQuotesType: SmartQuotesType.disabled,
                                    style: style,
                                    strutStyle: strut,
                                    decoration: const InputDecoration.collapsed(
                                      hintText: null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Line count and the longest line in columns, tabs counted as full stops.
  static (int, int) _measure(String text) {
    var lines = 1;
    var column = 0;
    var longest = 0;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit == 0x0A) {
        lines++;
        if (column > longest) longest = column;
        column = 0;
      } else if (unit == 0x09) {
        column += _tabColumns;
      } else {
        // Wide scripts take two cells; counting them as one would let a
        // CJK line wrap, and a wrapped line misaligns every number below.
        column += unit >= 0x1100 ? 2 : 1;
      }
    }
    if (column > longest) longest = column;
    return (lines, longest);
  }

  static double _advance(TextStyle style, BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
