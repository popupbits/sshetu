import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../file_browser_controller.dart';
import 'breadcrumb_bar.dart';

/// The breadcrumb, or an editable path field in its place — toggled by
/// tapping the breadcrumb itself or the pencil beside it.
///
/// A typed path is the fast way to a directory six levels down that many
/// breadcrumb taps cannot match in one step, and the one thing a click-only
/// breadcrumb can never do at all: paste a path copied from somewhere else.
class PathBar extends StatefulWidget {
  const PathBar({
    required this.currentPath,
    required this.segments,
    required this.labelOf,
    required this.onTap,
    required this.onSubmit,
    super.key,
  });

  final String currentPath;
  final List<String> segments;
  final String Function(String path) labelOf;
  final ValueChanged<String> onTap;

  /// Validates and navigates to the typed path. Returns the failure to show
  /// inline, or [PathSubmitResult.ok] once navigation has already happened —
  /// this widget never navigates itself, it only asks the controller to.
  final Future<PathSubmitResult> Function(String input) onSubmit;

  @override
  State<PathBar> createState() => _PathBarState();
}

class _PathBarState extends State<PathBar> {
  var _editing = false;
  var _submitting = false;
  PathSubmitResult? _error;
  late final _controller = TextEditingController();
  late final _focusNode = FocusNode()..addListener(_onFocusChange);

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Losing focus without a successful submit (a tap elsewhere, switching
    // panes) restores the breadcrumb rather than leaving a stale, unsubmitted
    // path field showing — the field's only job while unfocused is to be a
    // breadcrumb again.
    if (!_focusNode.hasFocus && _editing) {
      setState(() {
        _editing = false;
        _error = null;
      });
    }
  }

  void _startEditing() {
    _controller.text = widget.currentPath;
    setState(() {
      _editing = true;
      _error = null;
    });
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (result == PathSubmitResult.ok) {
        _editing = false;
        _error = null;
      } else {
        _error = result;
      }
    });
  }

  String _errorText(AppLocalizations l10n, PathSubmitResult result) =>
      switch (result) {
        PathSubmitResult.ok => '',
        PathSubmitResult.notAbsolute => l10n.filesPathNotAbsolute,
        PathSubmitResult.notFound => l10n.filesPathNotFound,
        PathSubmitResult.notADirectory => l10n.filesPathNotADirectory,
        PathSubmitResult.outsideSandbox => l10n.filesPathOutsideSandbox,
        PathSubmitResult.failed => l10n.filesPathFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (!_editing) {
      return SizedBox(
        height: Chrome.row,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _startEditing,
                child: BreadcrumbBar(
                  segments: widget.segments,
                  labelOf: widget.labelOf,
                  onTap: widget.onTap,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.filesPathEdit,
              icon: const Icon(PiconsRegular.pencilSimple, size: 14),
              visualDensity: VisualDensity.compact,
              onPressed: _startEditing,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _controller.text = widget.currentPath;
            _focusNode.unfocus();
          }
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          style: theme.textTheme.labelMedium,
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.filesPathHint,
            errorText: _error == null ? null : _errorText(l10n, _error!),
            prefixIcon: const Icon(PiconsRegular.mapPin, size: 16),
            suffixIcon: _submitting
                ? const Padding(
                    padding: EdgeInsets.all(Spacing.sm),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
    );
  }
}
