import 'dart:io' show Platform;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../domain/pane_drag.dart';

/// A pane that files can be dropped on: rows dragged from the other pane,
/// and — on a desktop — files and folders dragged in from the operating
/// system's file manager.
///
/// Highlights itself while something it would accept is over it, with
/// [label] saying what letting go will do.
class PaneDropTarget extends StatefulWidget {
  const PaneDropTarget({
    required this.label,
    required this.accepts,
    required this.onDrop,
    required this.child,
    this.onOsDrop,
    super.key,
  });

  final String label;

  /// Whether a row dragged from inside the app is welcome here.
  final bool Function(PaneDragData data) accepts;
  final void Function(PaneDragData data) onDrop;

  /// Paths dropped from outside the app. Null leaves OS drops alone.
  final void Function(List<String> paths)? onOsDrop;

  final Widget child;

  static const highlightKey = ValueKey('pane-drop-highlight');

  /// A platform capability, not a layout decision: only desktop operating
  /// systems hand an app files dragged from their file manager.
  static bool get osDropSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  State<PaneDropTarget> createState() => _PaneDropTargetState();
}

class _PaneDropTargetState extends State<PaneDropTarget> {
  var _osHover = false;

  @override
  Widget build(BuildContext context) {
    final onOsDrop = widget.onOsDrop;
    Widget target = DragTarget<PaneDragData>(
      onWillAcceptWithDetails: (details) => widget.accepts(details.data),
      onAcceptWithDetails: (details) => widget.onDrop(details.data),
      builder: (context, candidates, _) => _Highlight(
        active: _osHover || candidates.isNotEmpty,
        label: widget.label,
        child: widget.child,
      ),
    );
    if (onOsDrop != null && PaneDropTarget.osDropSupported) {
      target = DropTarget(
        // Off while another route covers this one: the plugin delivers
        // drops to every live target, visible or not.
        enable: TickerMode.valuesOf(context).enabled,
        onDragEntered: (_) => setState(() => _osHover = true),
        onDragExited: (_) => setState(() => _osHover = false),
        onDragDone: (details) {
          setState(() => _osHover = false);
          final paths = [
            for (final file in details.files)
              if (file.path.isNotEmpty) file.path,
          ];
          if (paths.isNotEmpty) onOsDrop(paths);
        },
        child: target,
      );
    }
    return target;
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.active,
    required this.label,
    required this.child,
  });

  final bool active;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              key: PaneDropTarget.highlightKey,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: scheme.primary,
                  width: BorderWidths.emphasis,
                ),
              ),
              child: Center(
                child: Material(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PiconsRegular.arrowFatLinesDown,
                          size: 16,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
