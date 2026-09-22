import 'host_group.dart';
import 'ssh_host.dart';

/// One section of the host list: a group and the hosts in it.
class HostSection {
  const HostSection({required this.group, required this.hosts});

  /// Null for the hosts in no group.
  final HostGroup? group;

  final List<SshHost> hosts;

  /// The key a section is collapsed under. Ungrouped has one too.
  String get key => group?.id ?? ungroupedKey;

  static const ungroupedKey = '';
}

/// Splits [hosts] into sections by group.
///
/// - Groups come in `sortOrder`, then name; the hosts in each keep the order
///   they arrived in, which is recency — sectioning must not undo that.
/// - Hosts in no group come last, and so do hosts naming a group that no
///   longer exists: a stale id must not make a server disappear.
/// - With [includeEmptyGroups] a group with no hosts still gets a section, so
///   a folder just created is visible and can be renamed or deleted. A filter
///   turns it off — a search that matched nothing in "Production" does not
///   need a "Production" header saying so.
/// - With no groups at all there is one section and no headers are wanted;
///   the list looks exactly as it did before groups existed.
List<HostSection> sectionHosts(
  List<SshHost> hosts,
  List<HostGroup> groups, {
  bool includeEmptyGroups = true,
}) {
  if (groups.isEmpty) return [HostSection(group: null, hosts: hosts)];

  final ordered = [...groups]
    ..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0
          ? byOrder
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  final byGroup = <String, List<SshHost>>{for (final g in ordered) g.id: []};
  final ungrouped = <SshHost>[];

  for (final host in hosts) {
    final bucket = host.groupId == null ? null : byGroup[host.groupId];
    (bucket ?? ungrouped).add(host);
  }

  return [
    for (final group in ordered)
      if (includeEmptyGroups || byGroup[group.id]!.isNotEmpty)
        HostSection(group: group, hosts: byGroup[group.id]!),
    if (ungrouped.isNotEmpty) HostSection(group: null, hosts: ungrouped),
  ];
}

/// Whether [host] carries every tag in [selected], case-insensitively.
///
/// All rather than any: the filter narrows, the same way the search does, so
/// adding a chip can only ever take hosts away.
bool hasAllTags(SshHost host, Set<String> selected) {
  if (selected.isEmpty) return true;
  final own = {for (final t in host.tags) t.toLowerCase()};
  return selected.every((t) => own.contains(t.toLowerCase()));
}
