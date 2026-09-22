/// A saved command, mirroring the `snippets` table.
///
/// Configuration, like a host or a tunnel: no secret lives here. The [body]
/// may carry `{{name}}` placeholders — see `SnippetTemplate` — which is where
/// anything that varies, or should not be written down, belongs.
class Snippet {
  const Snippet({
    required this.id,
    required this.label,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.tags = const [],
    this.sortOrder = 0,
  });

  final String id;

  /// What the list shows. Required: a row of bodies is unreadable.
  final String label;

  /// The shell text itself, possibly several lines.
  final String body;

  /// A note for later — what it does, when it is safe to run.
  final String? description;

  /// Already normalised through `HostTags`.
  final List<String> tags;

  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this snippet types more than one line.
  bool get isMultiline => body.trimRight().contains(RegExp('\r|\n'));

  /// Searches the label, the body and the tags — people remember a snippet
  /// by what it runs as often as by what they called it — and the
  /// description, which is where the "why" was written down.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return label.toLowerCase().contains(needle) ||
        body.toLowerCase().contains(needle) ||
        tags.any((t) => t.toLowerCase().contains(needle)) ||
        (description?.toLowerCase().contains(needle) ?? false);
  }

  Snippet copyWith({
    String? label,
    String? body,
    String? description,
    bool clearDescription = false,
    List<String>? tags,
    int? sortOrder,
    DateTime? updatedAt,
  }) => Snippet(
    id: id,
    label: label ?? this.label,
    body: body ?? this.body,
    description: clearDescription ? null : (description ?? this.description),
    tags: tags ?? this.tags,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String toString() => 'Snippet($id, $label)';
}
