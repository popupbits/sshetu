import '../../../core/ssh/sftp_service.dart';
import '../data/local_fs_service.dart';

/// What a row dragged out of one pane carries to the other.
///
/// Sealed, so a drop target switches on where the drag came from and the
/// compiler holds it to both cases: a remote entry dropped on the local pane
/// downloads, a local entry dropped on the remote pane uploads, and a drag
/// dropped back on its own pane is not a transfer at all.
sealed class PaneDragData {
  const PaneDragData();

  int get count;

  /// The first entry's name, for the drag's label.
  String get firstName;
}

/// Entries dragged from the remote pane.
class RemoteDrag extends PaneDragData {
  const RemoteDrag(this.entries);

  final List<RemoteEntry> entries;

  @override
  int get count => entries.length;

  @override
  String get firstName => entries.first.name;
}

/// Entries dragged from the local pane.
class LocalDrag extends PaneDragData {
  const LocalDrag(this.entries);

  final List<LocalEntry> entries;

  @override
  int get count => entries.length;

  @override
  String get firstName => entries.first.name;
}
