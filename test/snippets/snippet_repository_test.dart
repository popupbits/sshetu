import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/core/db/database.dart';
import 'package:sshetu/features/snippets/data/snippet_repository.dart';
import 'package:sshetu/features/snippets/domain/snippet.dart';

import '../support/test_database.dart';

/// Saved snippets against the real schema, migrations and all.
void main() {
  late AppDatabase database;
  late SnippetRepository repository;

  final now = DateTime.utc(2026, 1, 1);

  Snippet snippet(
    String id, {
    String? label,
    String body = 'uptime',
    String? description,
    List<String> tags = const [],
    int sortOrder = 0,
  }) => Snippet(
    id: id,
    label: label ?? id,
    body: body,
    description: description,
    tags: tags,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    database = await openTestDatabase();
    repository = SnippetRepository(database: database.raw);
  });

  tearDown(() => database.close());

  test('a saved snippet reads back with every field', () async {
    await repository.save(
      snippet(
        's1',
        label: 'Tail logs',
        body: 'cd {{dir:/var/log}}\ntail -f syslog',
        description: 'follow the system log',
        tags: ['logs', 'debug'],
        sortOrder: 3,
      ),
    );

    final read = await repository.byId('s1');
    expect(read, isNotNull);
    expect(read!.label, 'Tail logs');
    expect(read.body, 'cd {{dir:/var/log}}\ntail -f syslog');
    expect(read.description, 'follow the system log');
    expect(read.tags, ['logs', 'debug']);
    expect(read.sortOrder, 3);
    expect(read.createdAt, now);
    expect(read.updatedAt, now);
  });

  test('saving the same id replaces rather than duplicates', () async {
    await repository.save(snippet('s1', label: 'old'));
    await repository.save(
      snippet('s1').copyWith(label: 'new', body: 'df -h', updatedAt: now),
    );

    final all = await repository.all();
    expect(all, hasLength(1));
    expect(all.single.label, 'new');
    expect(all.single.body, 'df -h');
  });

  test('all() is in sort order, then by name ignoring case', () async {
    await repository.save(snippet('a', label: 'zeta'));
    await repository.save(snippet('b', label: 'Alpha'));
    await repository.save(snippet('c', label: 'beta'));
    await repository.save(snippet('d', label: 'first', sortOrder: -1));

    expect((await repository.all()).map((s) => s.label), [
      'first',
      'Alpha',
      'beta',
      'zeta',
    ]);
  });

  group('delete', () {
    test('is a tombstone: gone from reads, still in the table', () async {
      await repository.save(snippet('s1'));
      await repository.delete('s1', now: now.add(const Duration(hours: 1)));

      expect(await repository.all(), isEmpty);
      expect(await repository.byId('s1'), isNull);

      final rows = await database.raw.query('snippets');
      expect(rows, hasLength(1));
      expect(
        rows.single['deleted_at'],
        now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      );
      expect(rows.single['updated_at'], rows.single['deleted_at']);
    });

    test('leaves the other snippets alone', () async {
      await repository.save(snippet('s1'));
      await repository.save(snippet('s2'));
      await repository.delete('s1', now: now);

      expect((await repository.all()).map((s) => s.id), ['s2']);
    });

    test('saving a tombstoned id brings it back', () async {
      await repository.save(snippet('s1'));
      await repository.delete('s1', now: now);
      await repository.save(snippet('s1', label: 'back'));

      expect((await repository.byId('s1'))?.label, 'back');
    });
  });

  group('tags', () {
    test('go through the host tag rules on the way in', () async {
      await repository.save(
        snippet('s1', tags: ['  prod ', 'Prod', 'web, server', '', 'db']),
      );

      // Trimmed, de-duplicated case-insensitively (first spelling wins), a
      // comma turned into a space so it cannot split the column, empties
      // dropped.
      expect((await repository.byId('s1'))!.tags, ['prod', 'web server', 'db']);
    });

    test('are stored as one comma-separated column, null when none', () async {
      await repository.save(snippet('s1', tags: ['a', 'b']));
      await repository.save(snippet('s2'));

      final rows = {
        for (final row in await database.raw.query('snippets'))
          row['id']: row['tags'],
      };
      expect(rows['s1'], 'a,b');
      expect(rows['s2'], isNull);
    });
  });

  test('a blank description is stored as null', () async {
    await repository.save(snippet('s1', description: '   '));
    expect((await repository.byId('s1'))!.description, isNull);
  });

  group('matches', () {
    final s = snippet(
      's',
      label: 'Restart web',
      body: 'sudo systemctl restart nginx',
      description: 'after a deploy',
      tags: ['prod'],
    );

    test('label, body, tags and description, ignoring case', () {
      expect(s.matches('RESTART'), isTrue);
      expect(s.matches('nginx'), isTrue);
      expect(s.matches('pro'), isTrue);
      expect(s.matches('deploy'), isTrue);
      expect(s.matches(''), isTrue);
      expect(s.matches('apache'), isFalse);
    });
  });
}
