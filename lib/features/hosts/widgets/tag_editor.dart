import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/host_tags.dart';

/// Tags as removable chips, with a field that turns typing into more.
///
/// Enter or a comma commits what was typed; every tag goes through
/// [HostTags] on the way in, so the chips shown are exactly what will be
/// stored. Tags already used on other hosts are offered underneath — the
/// point of a tag is to be the *same* tag on several servers, and retyping
/// one invites `prod` and `Prod ` and `prd`.
class TagEditor extends StatefulWidget {
  const TagEditor({
    required this.tags,
    required this.controller,
    required this.onChanged,
    this.suggestions = const [],
    super.key,
  });

  final List<String> tags;

  /// The text being typed. Owned by the form, so Save can include a tag
  /// that was typed but never committed with Enter.
  final TextEditingController controller;
  final ValueChanged<List<String>> onChanged;

  /// Tags in use elsewhere, offered as one-tap additions.
  final List<String> suggestions;

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  TextEditingController get _controller => widget.controller;

  /// How many suggestions to show at once; more is a second tag cloud.
  static const _maxSuggestions = 6;

  void _add(Iterable<String> raw) {
    final next = HostTags.normalize([...widget.tags, ...raw]);
    if (next.length != widget.tags.length) widget.onChanged(next);
  }

  void _commit(String text) {
    _add(text.split(','));
    _controller.clear();
    setState(() {});
  }

  void _onChanged(String text) {
    // A comma is a separator here, never part of a tag: commit everything
    // before the last one and keep typing after it.
    if (text.contains(',')) {
      final parts = text.split(',');
      _add(parts.take(parts.length - 1));
      _controller.value = TextEditingValue(
        text: parts.last,
        selection: TextSelection.collapsed(offset: parts.last.length),
      );
    }
    setState(() {});
  }

  void _remove(String tag) =>
      widget.onChanged([...widget.tags.where((t) => t != tag)]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final have = {for (final t in widget.tags) t.toLowerCase()};
    final typed = _controller.text.trim().toLowerCase();
    final suggestions = widget.suggestions
        .where((s) => !have.contains(s.toLowerCase()))
        .where((s) => typed.isEmpty || s.toLowerCase().contains(typed))
        .take(_maxSuggestions)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.hostEditorTags,
            hintText: l10n.hostEditorTagsHint,
            prefixIcon: const Icon(PiconsRegular.tag),
            border: const OutlineInputBorder(),
            suffixIcon: typed.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.hostEditorTagAdd,
                    icon: const Icon(PiconsRegular.plus),
                    onPressed: () => _commit(_controller.text),
                  ),
          ),
          onChanged: _onChanged,
          onSubmitted: _commit,
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              for (final tag in widget.tags)
                InputChip(label: Text(tag), onDeleted: () => _remove(tag)),
            ],
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              for (final tag in suggestions)
                ActionChip(
                  avatar: const Icon(PiconsRegular.plus, size: 14),
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _add([tag]);
                    _controller.clear();
                    setState(() {});
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
