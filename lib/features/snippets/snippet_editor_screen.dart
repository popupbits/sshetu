import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/terminal_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/views.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../hosts/domain/host_tags.dart';
import '../hosts/widgets/tag_editor.dart';
import 'domain/snippet.dart';
import 'domain/snippet_template.dart';
import '../sessions/open_in_workspace.dart';
import 'snippets_controller.dart';

/// Add or edit one snippet.
class SnippetEditorScreen extends ConsumerStatefulWidget {
  const SnippetEditorScreen({this.snippetId, this.embedded = false, super.key});

  /// Null for a new snippet.
  final String? snippetId;

  /// True when this is a tab in the desktop workspace — the tab carries the
  /// title and the way out, as it does for the other editors.
  final bool embedded;

  @override
  ConsumerState<SnippetEditorScreen> createState() =>
      _SnippetEditorScreenState();
}

class _SnippetEditorScreenState extends ConsumerState<SnippetEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _body = TextEditingController();
  final _description = TextEditingController();
  final _tagInput = TextEditingController();
  var _tags = <String>[];
  var _loaded = false;
  Snippet? _existing;

  @override
  void dispose() {
    _label.dispose();
    _body.dispose();
    _description.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _load(List<Snippet> snippets) {
    if (_loaded || widget.snippetId == null) {
      _loaded = true;
      return;
    }
    final snippet = snippets.where((s) => s.id == widget.snippetId).firstOrNull;
    if (snippet == null) return;
    _loaded = true;
    _existing = snippet;
    _label.text = snippet.label;
    _body.text = snippet.body;
    _description.text = snippet.description ?? '';
    _tags = [...snippet.tags];
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now().toUtc();
    // A tag typed but never committed with Enter is still what the user
    // meant — the host editor makes the same call.
    final tags = HostTags.normalize([..._tags, ..._tagInput.text.split(',')]);
    final description = _description.text.trim();
    final existing = _existing;

    final snippet = existing == null
        ? Snippet(
            id: SnippetsController.newId(),
            label: _label.text.trim(),
            body: _body.text,
            description: description.isEmpty ? null : description,
            tags: tags,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            label: _label.text.trim(),
            body: _body.text,
            description: description.isEmpty ? null : description,
            clearDescription: description.isEmpty,
            tags: tags,
            updatedAt: now,
          );

    await ref.read(snippetsControllerProvider).save(snippet);
    if (mounted) closeOpenedScreen(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snippets = ref.watch(snippetsProvider);
    snippets.whenData(_load);
    final isNew = widget.snippetId == null;
    final suggestions = HostTags.union([
      for (final s in snippets.value ?? const <Snippet>[]) s.tags,
    ]);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: widget.embedded
            ? null
            : Text(isNew ? l10n.snippetEditorNew : l10n.snippetEditorEdit),
        actions: [
          TextButton(
            key: const Key('snippetEditor.save'),
            onPressed: _save,
            child: Text(l10n.hostEditorSave),
          ),
        ],
      ),
      body: ContentWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              TextFormField(
                key: const Key('snippetEditor.label'),
                controller: _label,
                autofocus: isNew,
                decoration: InputDecoration(
                  labelText: l10n.snippetEditorLabel,
                  hintText: l10n.snippetEditorLabelHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.hostEditorRequired
                    : null,
              ),
              const SizedBox(height: Spacing.lg),
              TextFormField(
                key: const Key('snippetEditor.body'),
                controller: _body,
                minLines: 4,
                maxLines: 14,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                style: Mono.apply(theme.textTheme.bodyMedium),
                decoration: InputDecoration(
                  labelText: l10n.snippetEditorBody,
                  hintText: l10n.snippetEditorBodyHint(
                    SnippetSyntax.bodyExample,
                  ),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.hostEditorRequired
                    : null,
              ),
              const SizedBox(height: Spacing.sm),
              _VariablesSummary(body: _body.text),
              const SizedBox(height: Spacing.lg),
              TextFormField(
                key: const Key('snippetEditor.description'),
                controller: _description,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.snippetEditorDescription,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              SectionLabel(l10n.snippetEditorTags),
              TagEditor(
                tags: _tags,
                controller: _tagInput,
                suggestions: suggestions,
                onChanged: (tags) => setState(() => _tags = tags),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the body will ask for and what it fills in by itself, as it is
/// typed — the syntax is only worth having if its effect is visible.
class _VariablesSummary extends StatelessWidget {
  const _VariablesSummary({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final variables = SnippetTemplate.parse(body).variables;
    final builtins = SnippetBuiltins.all.toSet();
    final asks = [
      for (final v in variables)
        if (!builtins.contains(v.name)) v.name,
    ];
    final fills = [
      for (final v in variables)
        if (builtins.contains(v.name)) v.name,
    ];

    final text = asks.isEmpty && fills.isEmpty
        ? l10n.snippetEditorVariablesHint(
            SnippetSyntax.example,
            SnippetSyntax.defaultExample,
            SnippetSyntax.builtinList,
          )
        : [
            if (asks.isNotEmpty) l10n.snippetEditorAsks(asks.join(', ')),
            if (fills.isNotEmpty) l10n.snippetEditorFills(fills.join(', ')),
          ].join(' · ');

    return Text(
      text,
      key: const Key('snippetEditor.variables'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
