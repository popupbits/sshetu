import 'package:flutter_test/flutter_test.dart';
import 'package:picons/picons.dart';
import 'package:sshetu/features/palette/domain/palette_item.dart';
import 'package:sshetu/features/palette/domain/palette_ranking.dart';
import 'package:sshetu/features/palette/widgets/highlighted_text.dart';

void main() {
  PaletteItem item(
    String id,
    String title, {
    String? subtitle,
    PaletteCategory category = PaletteCategory.host,
    List<String> keywords = const [],
  }) => PaletteItem(
    id: id,
    title: title,
    subtitle: subtitle,
    category: category,
    icon: PiconsRegular.hardDrives,
    keywords: keywords,
    actions: [
      PaletteAction(
        id: 'go',
        label: 'Go',
        icon: PiconsRegular.play,
        run: (_, _) {},
      ),
    ],
  );

  final items = [
    item('host:a', 'web-01', subtitle: 'deploy@web-01.example.com'),
    item('host:b', 'database', subtitle: 'root@db.internal'),
    item('host:c', 'bastion', subtitle: 'me@jump.example.com'),
    item(
      'tunnel:t',
      'Grafana',
      subtitle: '127.0.0.1:3000 → grafana:3000',
      category: PaletteCategory.tunnel,
    ),
    item('action:newHost', 'Add host', category: PaletteCategory.action),
  ];

  List<String> ids(List<RankedPaletteItem> ranked) => [
    for (final r in ranked) r.item.id,
  ];

  group('an empty query', () {
    test('keeps source order with no recents', () {
      expect(
        ids(rankPaletteItems(items, '')),
        ids([for (final i in items) RankedPaletteItem(i)]),
      );
    });

    test('floats recents to the top, most recent first', () {
      final ranked = rankPaletteItems(
        items,
        '',
        recents: ['action:newHost', 'host:c'],
      );
      expect(ids(ranked).take(2), ['action:newHost', 'host:c']);
      expect(ranked[0].recent, isTrue);
      expect(ranked[1].recent, isTrue);
      expect(ranked[2].recent, isFalse);
      // Every item still appears exactly once.
      expect(ids(ranked).toSet(), ids(ranked.toList()).toSet());
      expect(ranked, hasLength(items.length));
    });

    test('skips recents that no longer exist', () {
      final ranked = rankPaletteItems(
        items,
        '',
        recents: ['host:deleted', 'host:b'],
      );
      expect(ids(ranked).first, 'host:b');
      expect(ranked, hasLength(items.length));
    });
  });

  group('a query', () {
    test('keeps only matches, best first', () {
      final ranked = rankPaletteItems(items, 'db');
      // "database" matches on its title; nothing else has d then b in its
      // title, but "root@db.internal" does in the subtitle — the title wins.
      expect(ids(ranked).first, 'host:b');
      expect(ids(ranked), isNot(contains('host:c')));
    });

    test('a title match outranks a subtitle match', () {
      final ranked = rankPaletteItems([
        item('x', 'jump', subtitle: 'nothing'),
        item('y', 'other', subtitle: 'jump'),
      ], 'jump');
      expect(ids(ranked), ['x', 'y']);
      expect(ranked[0].titleHighlights, [0, 1, 2, 3]);
      expect(ranked[1].titleHighlights, isEmpty);
      expect(ranked[1].subtitleHighlights, [0, 1, 2, 3]);
    });

    test('matches the category name through categoryLabel', () {
      final ranked = rankPaletteItems(
        items,
        'tunnel',
        categoryLabel: (c) => c.name,
      );
      expect(ids(ranked), ['tunnel:t']);
      expect(ranked.single.titleHighlights, isEmpty);
    });

    test('matches hidden keywords', () {
      final ranked = rankPaletteItems([
        item('k', 'Generate key', keywords: ['ssh-keygen']),
      ], 'keygen');
      expect(ids(ranked), ['k']);
    });

    test('a recent item wins a tie', () {
      final twins = [item('one', 'deploy'), item('two', 'deploy')];
      expect(ids(rankPaletteItems(twins, 'dep')), ['one', 'two']);
      expect(ids(rankPaletteItems(twins, 'dep', recents: ['two'])), [
        'two',
        'one',
      ]);
    });

    test('no match is an empty list', () {
      expect(rankPaletteItems(items, 'zzz'), isEmpty);
    });
  });

  group('highlight runs', () {
    test('split text into matched and unmatched runs', () {
      expect(HighlightedText.runs('web-01', [0, 1, 2]), [
        ('web', true),
        ('-01', false),
      ]);
      expect(HighlightedText.runs('abc', [1]), [
        ('a', false),
        ('b', true),
        ('c', false),
      ]);
      expect(HighlightedText.runs('abc', const []), [('abc', false)]);
      expect(HighlightedText.runs('', const []), isEmpty);
    });
  });
}
