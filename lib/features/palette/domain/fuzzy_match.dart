import 'package:flutter/foundation.dart';

/// How well a query matched a piece of text, and which characters it used.
@immutable
class FuzzyMatch {
  const FuzzyMatch(this.score, this.indices);

  /// Higher is better. Only meaningful relative to other matches of the same
  /// query.
  final int score;

  /// The positions in the text the query's characters landed on, ascending —
  /// what the palette draws in bold.
  final List<int> indices;

  @override
  String toString() => 'FuzzyMatch($score, $indices)';
}

/// The scoring weights, named so a test can talk about them.
abstract final class FuzzyWeights {
  /// Every matched character.
  static const int match = 1;

  /// A character at the start of a word: after a separator, or an upper-case
  /// letter after a lower-case one (`camelCase`).
  static const int wordStart = 8;

  /// On top of [wordStart], for the very first character of the text — the
  /// query is a prefix.
  static const int prefix = 6;

  /// A character right after the previous matched one.
  static const int consecutive = 8;

  /// Taken off for every skipped character between two matched ones, capped
  /// at [maxGapPenalty] so one long gap does not sink an otherwise good match.
  static const int gap = 1;
  static const int maxGapPenalty = 6;

  /// Taken off per character of text the match did not cover, so the shorter
  /// of two equally good candidates wins: "Keys" over "Keyboard settings" for
  /// `key`.
  static const int lengthPenaltyDivisor = 8;
}

const _separators = ' -_./:@\\()[]+,';

bool _isWordStart(String text, int i) {
  if (i == 0) return true;
  final previous = text[i - 1];
  if (_separators.contains(previous)) return true;
  final current = text[i];
  final previousIsLower = previous != previous.toUpperCase();
  final currentIsUpper =
      current != current.toLowerCase() && current == current.toUpperCase();
  return previousIsLower && currentIsUpper;
}

/// Matches [query] against [text] as a case-insensitive subsequence, choosing
/// the placement with the best score rather than the first one found.
///
/// Whitespace in the query is ignored, so `prod db` finds
/// `production-database`. Returns null when the query's characters do not all
/// appear in order. An empty query matches everything with a score of zero and
/// no highlights.
///
/// A dynamic programme over (query position, text position): each cell is the
/// best score with that query character placed on that text character, built
/// from the best placement of the previous query character before it. That is
/// O(query × text²) at worst, which for a palette's short labels is nothing.
FuzzyMatch? fuzzyMatch(String query, String text) {
  final needle = query.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  if (needle.isEmpty) return const FuzzyMatch(0, []);
  final hay = text.toLowerCase();
  final n = needle.length;
  final m = hay.length;
  if (n > m) return null;

  // Cheap rejection before the table: is it a subsequence at all?
  var probe = 0;
  for (var j = 0; j < m && probe < n; j++) {
    if (hay[j] == needle[probe]) probe++;
  }
  if (probe < n) return null;

  const impossible = -1 << 30;
  final score = List.generate(n, (_) => List.filled(m, impossible));
  final from = List.generate(n, (_) => List.filled(m, -1));

  int charBonus(int j) {
    var bonus = FuzzyWeights.match;
    if (_isWordStart(text, j)) bonus += FuzzyWeights.wordStart;
    if (j == 0) bonus += FuzzyWeights.prefix;
    return bonus;
  }

  for (var j = 0; j < m; j++) {
    if (hay[j] == needle[0]) score[0][j] = charBonus(j);
  }

  for (var i = 1; i < n; i++) {
    for (var j = i; j < m; j++) {
      if (hay[j] != needle[i]) continue;
      var best = impossible;
      var bestFrom = -1;
      for (var k = i - 1; k < j; k++) {
        final previous = score[i - 1][k];
        if (previous == impossible) continue;
        final skipped = j - k - 1;
        final candidate = skipped == 0
            ? previous + FuzzyWeights.consecutive
            : previous -
                  (skipped * FuzzyWeights.gap).clamp(
                    0,
                    FuzzyWeights.maxGapPenalty,
                  );
        if (candidate > best) {
          best = candidate;
          bestFrom = k;
        }
      }
      if (bestFrom < 0) continue;
      score[i][j] = best + charBonus(j);
      from[i][j] = bestFrom;
    }
  }

  var end = -1;
  var top = impossible;
  for (var j = n - 1; j < m; j++) {
    if (score[n - 1][j] > top) {
      top = score[n - 1][j];
      end = j;
    }
  }
  if (end < 0) return null;

  final indices = List.filled(n, 0);
  for (var i = n - 1, j = end; i >= 0; i--) {
    indices[i] = j;
    j = from[i][j];
  }

  final unmatched = m - n;
  return FuzzyMatch(
    top - unmatched ~/ FuzzyWeights.lengthPenaltyDivisor,
    indices,
  );
}
