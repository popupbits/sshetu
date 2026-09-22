import 'package:flutter_test/flutter_test.dart';
import 'package:sshetu/features/hosts/domain/host_group.dart';
import 'package:sshetu/features/hosts/domain/host_sections.dart';
import 'package:sshetu/features/hosts/domain/ssh_host.dart';

/// Splitting the host list into group sections.
void main() {
  final now = DateTime.utc(2026);

  SshHost host(String id, {String? group, List<String> tags = const []}) =>
      SshHost(
        id: id,
        label: id,
        hostname: '$id.example.com',
        username: 'root',
        groupId: group,
        tags: tags,
        createdAt: now,
        updatedAt: now,
      );

  HostGroup folder(String id, {String? name, int order = 0}) => HostGroup(
    id: id,
    name: name ?? id,
    sortOrder: order,
    createdAt: now,
    updatedAt: now,
  );

  test('no groups is one headerless section, in the order given', () {
    final hosts = [host('b'), host('a')];
    final sections = sectionHosts(hosts, const []);

    expect(sections, hasLength(1));
    expect(sections.single.group, isNull);
    expect(sections.single.hosts.map((h) => h.id), ['b', 'a']);
  });

  test('hosts land in their group; ungrouped comes last', () {
    final sections = sectionHosts(
      [host('web', group: 'prod'), host('laptop'), host('db', group: 'prod')],
      [folder('prod')],
    );

    expect(sections.map((s) => s.group?.id), ['prod', null]);
    // Recency order within a section survives the split.
    expect(sections.first.hosts.map((h) => h.id), ['web', 'db']);
    expect(sections.last.hosts.map((h) => h.id), ['laptop']);
    expect(sections.last.key, HostSection.ungroupedKey);
  });

  test('groups sort by order, then name case-insensitively', () {
    final sections = sectionHosts(const [], [
      folder('z', name: 'zeta'),
      folder('b', name: 'Beta'),
      folder('a', name: 'alpha'),
      folder('first', name: 'Zzz', order: -1),
    ]);

    expect(sections.map((s) => s.group!.name), [
      'Zzz',
      'alpha',
      'Beta',
      'zeta',
    ]);
  });

  test('a host naming a missing group is ungrouped, never lost', () {
    final sections = sectionHosts(
      [host('orphan', group: 'deleted')],
      [folder('prod')],
    );

    expect(sections.last.group, isNull);
    expect(sections.last.hosts.single.id, 'orphan');
  });

  test('empty groups show unless a filter is active', () {
    final hosts = [host('laptop')];
    final groups = [folder('prod')];

    expect(sectionHosts(hosts, groups).map((s) => s.group?.id), ['prod', null]);
    expect(
      sectionHosts(
        hosts,
        groups,
        includeEmptyGroups: false,
      ).map((s) => s.group?.id),
      [null],
    );
  });

  test('no ungrouped section when every host is filed', () {
    final sections = sectionHosts(
      [host('web', group: 'prod')],
      [folder('prod')],
    );
    expect(sections.map((s) => s.group?.id), ['prod']);
  });

  group('hasAllTags', () {
    final tagged = host('web', tags: const ['Prod', 'eu']);

    test('no selection matches everything', () {
      expect(hasAllTags(host('x'), const {}), isTrue);
    });

    test('needs every selected tag, case-insensitively', () {
      expect(hasAllTags(tagged, {'prod'}), isTrue);
      expect(hasAllTags(tagged, {'prod', 'EU'}), isTrue);
      expect(hasAllTags(tagged, {'prod', 'us'}), isFalse);
    });
  });
}
