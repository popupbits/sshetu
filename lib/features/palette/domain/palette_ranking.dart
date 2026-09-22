import 'package:flutter/foundation.dart';

import 'fuzzy_match.dart';
import 'palette_item.dart';

/// An item as the palette draws it: where it ranked and which characters to
/// highlight.
@immutable
class RankedPaletteItem {
  const RankedPaletteItem(
    this.item, {
    this.titleHighlights = const [],
    this.subtitleHighlights = const [],
    this.recent = false,
  });

  final PaletteItem item;
  final List<int> titleHighlights;
  final List<int> subtitleHighlights;

  /// Used recently — the row says so when the query is empty.
  final bool recent;
}

/// What a match on something other than the title costs, so a title match
/// always has the edge over an equally good subtitle or keyword match.
abstract final class PaletteRankWeights {
  static const int subtitlePenalty = 10;
  static const int keywordPenalty = 15;

  /// A recently used item wins ties and near-ties.
  static const int recentBonus = 4;
}

/// Orders [items] for [query].
///
/// With an empty query: the [recents] that still exist, most recent first,
/// then everything else in the order the sources gave it. With a query: only
/// the items that match — on the title, else the subtitle, else a keyword or
/// the category's name — best first, ties kept in source order.
///
/// [categoryLabel] names a category in the user's language, so typing
/// `tunnel` lists the tunnels.
List<RankedPaletteItem> rankPaletteItems(
  List<PaletteItem> items,
  String query, {
  List<String> recents = const [],
  String Function(PaletteCategory category)? categoryLabel,
}) {
  final recentRank = <String, int>{
    for (var i = 0; i < recents.length; i++) recents[i]: i,
  };

  if (query.trim().isEmpty) {
    final byId = {for (final item in items) item.id: item};
    final seen = <String>{};
    return [
      for (final id in recents)
        if (byId[id] case final item? when seen.add(id))
          RankedPaletteItem(item, recent: true),
      for (final item in items)
        if (!seen.contains(item.id)) RankedPaletteItem(item),
    ];
  }

  final scored = <(int score, int order, RankedPaletteItem ranked)>[];
  for (var order = 0; order < items.length; order++) {
    final item = items[order];
    final recent = recentRank.containsKey(item.id);
    final bonus = recent ? PaletteRankWeights.recentBonus : 0;

    final title = fuzzyMatch(query, item.title);
    if (title != null) {
      scored.add((
        title.score + bonus,
        order,
        RankedPaletteItem(item, titleHighlights: title.indices, recent: recent),
      ));
      continue;
    }

    final subtitle = item.subtitle;
    final sub = subtitle == null ? null : fuzzyMatch(query, subtitle);
    if (sub != null) {
      scored.add((
        sub.score - PaletteRankWeights.subtitlePenalty + bonus,
        order,
        RankedPaletteItem(
          item,
          subtitleHighlights: sub.indices,
          recent: recent,
        ),
      ));
      continue;
    }

    FuzzyMatch? keyword;
    for (final word in [
      ...item.keywords,
      if (categoryLabel != null) categoryLabel(item.category),
    ]) {
      final match = fuzzyMatch(query, word);
      if (match != null && (keyword == null || match.score > keyword.score)) {
        keyword = match;
      }
    }
    if (keyword != null) {
      scored.add((
        keyword.score - PaletteRankWeights.keywordPenalty + bonus,
        order,
        RankedPaletteItem(item, recent: recent),
      ));
    }
  }

  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
  });
  return [for (final entry in scored) entry.$3];
}
