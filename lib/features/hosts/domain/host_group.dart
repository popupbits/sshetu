/// A folder of hosts.
///
/// One level in the UI. The table carries `parent_id` so folders *can* nest,
/// but nothing here reads it yet: a list of collapsible sections is what a
/// phone can show well, and a tree of them is not.
class HostGroup {
  const HostGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  final String id;
  final String name;

  /// Position among the other groups; ties fall back to [name].
  final int sortOrder;

  final DateTime createdAt;
  final DateTime updatedAt;

  HostGroup copyWith({String? name, int? sortOrder, DateTime? updatedAt}) =>
      HostGroup(
        id: id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is HostGroup &&
      other.id == id &&
      other.name == name &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, sortOrder, createdAt, updatedAt);

  @override
  String toString() => 'HostGroup($id, $name)';
}
