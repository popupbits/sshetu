import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';

/// Find-in-scrollback state for one terminal.
///
/// xterm2 already does the hard part — `Terminal.search` walks soft-wrapped
/// rows as one logical line, and `TerminalController.setSearchHighlights`
/// anchors the matches to the buffer so they stay on their text as output
/// scrolls. This class is the state a find bar needs on top: the query and its
/// options, which match is current, and moving between them.
///
/// **Order.** Matches are counted from the newest (bottom) up, and "next"
/// means further back in history. In a terminal you almost always search for
/// something that has already scrolled past, so the first match shown is the
/// most recent one and Enter keeps going up. "3 of 17" is the third most
/// recent.
class TerminalFind extends ChangeNotifier {
  TerminalFind({required this.terminal, required this.controller}) {
    terminal.addListener(_onTerminalChanged);
  }

  final Terminal terminal;
  final TerminalController controller;

  /// The most matches a search collects. xterm2 caps its own allocation; the
  /// count reads "1000+" once it is reached.
  static const maxResults = 1000;

  String _query = '';
  bool _caseSensitive = false;
  bool _useRegex = false;
  bool _invalidPattern = false;
  List<TerminalSearchMatch> _matches = const [];

  /// Index into [_matches], which xterm2 orders top to bottom. -1 for none.
  int _index = -1;

  /// Set when output arrives after a search, so the next step re-runs it and
  /// finds matches printed since.
  bool _stale = false;

  String get query => _query;
  bool get caseSensitive => _caseSensitive;
  bool get useRegex => _useRegex;

  /// True when regex mode is on and the query does not compile.
  bool get invalidPattern => _invalidPattern;

  int get matchCount => _matches.length;

  /// Whether the search stopped at [maxResults].
  bool get capped => _matches.length >= maxResults;

  /// 1-based, counted from the newest match. 0 when there are none.
  int get currentPosition => _index < 0 ? 0 : _matches.length - _index;

  /// The current match's cells, for scrolling it into view.
  BufferRangeLine? get currentRange {
    if (_index < 0) return null;
    final highlights = controller.searchHighlights;
    if (_index < highlights.length) {
      // The anchored copy: it has followed the text if the buffer moved.
      final anchored = highlights[_index].rangeFor(terminal.buffer);
      if (anchored != null) return anchored;
    }
    return _matches[_index].range;
  }

  set query(String value) {
    if (value == _query) return;
    _query = value;
    _search(keepPosition: false);
  }

  set caseSensitive(bool value) {
    if (value == _caseSensitive) return;
    _caseSensitive = value;
    _search(keepPosition: false);
  }

  set useRegex(bool value) {
    if (value == _useRegex) return;
    _useRegex = value;
    _search(keepPosition: false);
  }

  /// One match further back in history, wrapping to the newest.
  void next() => _step(-1);

  /// One match more recent, wrapping to the oldest.
  void previous() => _step(1);

  /// Drops the highlights. The query is kept, so reopening the bar picks up
  /// where it left off.
  void clear() {
    _matches = const [];
    _index = -1;
    _invalidPattern = false;
    controller.clearSearchHighlights();
    notifyListeners();
  }

  /// Runs the current query again — reopening the bar, for one.
  void refresh() => _search(keepPosition: false);

  void _step(int delta) {
    if (_stale) _search(keepPosition: true);
    if (_matches.isEmpty) return;
    final count = _matches.length;
    _index = (_index + delta) % count;
    if (_index < 0) _index += count;
    controller.setCurrentSearchHighlight(_index);
    notifyListeners();
  }

  void _search({required bool keepPosition}) {
    final anchor = keepPosition ? currentRange?.begin : null;
    _stale = false;
    _invalidPattern = false;

    if (_query.isEmpty) {
      _matches = const [];
    } else {
      try {
        _matches = terminal.search(
          _query,
          caseSensitive: _caseSensitive,
          useRegex: _useRegex,
          maxResults: maxResults,
        );
      } on FormatException {
        _matches = const [];
        _invalidPattern = true;
      }
    }

    if (_matches.isEmpty) {
      _index = -1;
      controller.clearSearchHighlights();
      notifyListeners();
      return;
    }

    _index = _matches.length - 1;
    if (anchor != null) {
      // Stay on the match the user was looking at. If it has gone, stay on
      // the nearest one above where it was.
      for (var i = _matches.length - 1; i >= 0; i--) {
        final begin = _matches[i].range.begin;
        if (begin.y < anchor.y ||
            (begin.y == anchor.y && begin.x <= anchor.x)) {
          _index = i;
          break;
        }
      }
    }

    controller.setSearchHighlights(terminal.buffer, [
      for (final match in _matches) match.range,
    ], currentIndex: _index);
    notifyListeners();
  }

  void _onTerminalChanged() {
    if (_matches.isNotEmpty || _query.isNotEmpty) _stale = true;
  }

  @override
  void dispose() {
    terminal.removeListener(_onTerminalChanged);
    controller.clearSearchHighlights();
    super.dispose();
  }
}
