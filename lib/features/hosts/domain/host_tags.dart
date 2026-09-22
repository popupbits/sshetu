/// Tags are stored as one comma-separated column, so every tag that reaches
/// the database goes through here first.
///
/// The column format is the reason for the rules: a comma inside a tag would
/// split it into two on the way back out, and an empty tag becomes a blank
/// chip. Whitespace is collapsed so `prod ` and `prod` are the same tag, and
/// duplicates are dropped case-insensitively — the first spelling wins, so
/// someone who typed `Prod` keeps their capital.
abstract final class HostTags {
  /// The longest a single tag may be. A tag is a label on a chip, not a note.
  static const int maxLength = 32;

  /// [raw] as a storable tag, or null when nothing usable is left.
  static String? sanitize(String raw) {
    final cleaned = raw
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength).trimRight()
        : cleaned;
  }

  /// Every tag in [raw] sanitized, empties dropped, duplicates removed.
  static List<String> normalize(Iterable<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final tag in raw) {
      final clean = sanitize(tag);
      if (clean == null) continue;
      if (seen.add(clean.toLowerCase())) result.add(clean);
    }
    return result;
  }

  /// Splits text the user typed, or a stored column, into tags.
  ///
  /// Commas separate; spaces do not, so `web server` stays one tag.
  static List<String> parse(String? text) =>
      text == null || text.isEmpty ? const [] : normalize(text.split(','));

  /// The column value for [tags], or null when there are none.
  static String? join(Iterable<String> tags) {
    final clean = normalize(tags);
    return clean.isEmpty ? null : clean.join(',');
  }

  /// Every distinct tag across [tagLists], sorted case-insensitively.
  static List<String> union(Iterable<List<String>> tagLists) =>
      normalize(tagLists.expand((t) => t)).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
