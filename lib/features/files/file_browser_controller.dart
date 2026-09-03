import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
// Unrestricted import, not `show AsyncValue`: `.whenData` and `.when` are
// extension methods (`AsyncValueExtensions`, a different top-level name), so
// a `show` combinator naming only the class would hide them.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/ssh/sftp_service.dart';
import '../../core/util/sort_entries.dart';
import 'data/local_fs_service.dart';
import 'domain/browse_path.dart';

/// Which side of the dual-pane browser is showing on a phone, where there is
/// only room for one at a time.
enum BrowserPane { remote, local }

enum TransferDirection { download, upload }

/// What went wrong (if anything) when a typed path was submitted — shared by
/// `FileBrowserController.submitRemotePath` and `submitLocalPath` so the
/// path-entry field can render the same switch on either pane.
enum PathSubmitResult {
  ok,
  notAbsolute,
  notFound,
  notADirectory,

  /// Local pane only: the resolved path is real, but outside the sandbox a
  /// mobile platform confines this pane to. See
  /// [FileBrowserController.localIsSandboxed].
  outsideSandbox,
  failed,
}

/// One transfer's progress, for the list under the panes.
///
/// Immutable, like every model in this app: the controller replaces a job in
/// its list rather than mutating one in place, so a widget watching the list
/// sees a genuinely new value instead of the same reference before and after.
class TransferJob {
  const TransferJob({
    required this.id,
    required this.name,
    required this.direction,
    this.total,
    this.transferred = 0,
    this.error,
    this.done = false,
    this.cancelled = false,
    this.cancelToken,
  });

  final String id;
  final String name;
  final TransferDirection direction;

  /// Bytes to move, when the source reported a size. Null means the progress
  /// row can show bytes moved but not a percentage.
  final int? total;
  final int transferred;

  /// Set when the transfer failed. Safe to show — it comes from
  /// [SftpException] or [LocalFsException], never a raw platform error.
  final String? error;

  /// True once the transfer has finished, successfully, with an error, or
  /// cancelled.
  final bool done;

  /// True when this job stopped because [cancelToken] was cancelled, not
  /// because it failed — kept separate from [error] so the transfer row can
  /// show "Cancelled" rather than reading like something broke.
  final bool cancelled;

  /// Null once [done] — a cancel button with nothing left to cancel would be
  /// a lie.
  final SftpCancelToken? cancelToken;

  bool get failed => error != null;
  bool get canCancel => !done && cancelToken != null;

  TransferJob copyWith({
    int? transferred,
    int? total,
    String? error,
    bool? done,
    bool? cancelled,
  }) => TransferJob(
    id: id,
    name: name,
    direction: direction,
    total: total ?? this.total,
    transferred: transferred ?? this.transferred,
    error: error ?? this.error,
    done: done ?? this.done,
    cancelled: cancelled ?? this.cancelled,
    cancelToken: (done ?? this.done) ? null : cancelToken,
  );
}

/// The state and behaviour behind the dual-pane file browser: one directory
/// listing per pane, navigation, and the transfers moving files between them.
///
/// A plain [ChangeNotifier] rather than a Riverpod provider, for the same
/// reason `TerminalSession` is one: this wraps one screen's SFTP channel, is
/// constructed with the resources that screen was opened for, and does not
/// need to survive being navigated away from the way a session tab does. See
/// `lib/core/terminal/terminal_session.dart`.
class FileBrowserController extends ChangeNotifier {
  FileBrowserController({
    required SftpService sftp,
    required String localRoot,
    LocalFsService localFs = const LocalFsService(),
    String remoteRoot = '/',
    p.Context? localContext,
    // Null on desktop, where the local pane can browse the whole
    // filesystem. Non-null on iOS/Android — see `file_browser_screen.dart`
    // for which directory this is set to and why: neither platform's
    // filesystem is something this app can honestly claim to browse in
    // general, so the pane is confined to a directory it actually has
    // access to rather than silently showing an empty root.
    String? localBoundary,
  }) : // `this._sftp`/`this._localFs` are not an option here even though the
       // field name matches: an initializing formal for a *named* parameter
       // takes the field's own (private) identifier as its external name,
       // which no caller outside this library could then spell.
       // ignore: prefer_initializing_formals
       _sftp = sftp,
       // ignore: prefer_initializing_formals
       _localFs = localFs,
       _remoteNav = BrowsePath(p.posix),
       // Real local browsing wants the platform's own separator; a test wants
       // a fixed one so the assertions do not depend on the OS running them.
       _localNav = BrowsePath(localContext ?? p.context),
       _remotePath = remoteRoot,
       _localPath = localRoot,
       // Same reason as `_sftp`/`_localFs` above.
       // ignore: prefer_initializing_formals
       _localBoundary = localBoundary {
    unawaited(refreshRemote());
    unawaited(refreshLocal());
  }

  final SftpService _sftp;
  final LocalFsService _localFs;
  final BrowsePath _remoteNav;
  final BrowsePath _localNav;
  final String? _localBoundary;

  bool _disposed = false;

  String _remotePath;
  String get remotePath => _remotePath;

  String _localPath;
  String get localPath => _localPath;

  /// Whether the local pane is confined to [_localBoundary] rather than free
  /// to browse the whole device filesystem.
  bool get localIsSandboxed => _localBoundary != null;

  AsyncValue<List<RemoteEntry>> _remoteEntries = const AsyncValue.loading();
  AsyncValue<List<LocalEntry>> _localEntries = const AsyncValue.loading();

  /// The raw listing, filtered for hidden files and sorted per the current
  /// pane settings. A computed getter rather than storing the sorted list
  /// directly: re-sorting or toggling hidden files should not require
  /// touching the network or the filesystem again, just recomputing this.
  AsyncValue<List<RemoteEntry>> get remoteEntries => _remoteEntries.whenData(
    (entries) => sortFileEntries(
      _visible(entries, _remoteShowHidden, (e) => e.name),
      isDirectory: (e) => e.isDirectory,
      name: (e) => e.name,
      size: (e) => e.size,
      modified: (e) => e.modified,
      field: _remoteSortField,
      ascending: _remoteSortAscending,
    ),
  );

  AsyncValue<List<LocalEntry>> get localEntries => _localEntries.whenData(
    (entries) => sortFileEntries(
      _visible(entries, _localShowHidden, (e) => e.name),
      isDirectory: (e) => e.isDirectory,
      name: (e) => e.name,
      size: (e) => e.size,
      modified: (e) => e.modified,
      field: _localSortField,
      ascending: _localSortAscending,
    ),
  );

  /// A remote `~` is mostly dotfiles, and a first-time browser of one buried
  /// under `.config`, `.cache` and `.ssh` is not what "show me this folder"
  /// meant — so hidden entries stay filtered out until asked for, on both
  /// panes, the same way every desktop file manager defaults.
  static List<T> _visible<T>(
    List<T> entries,
    bool showHidden,
    String Function(T) name,
  ) => showHidden
      ? entries
      : entries.where((e) => !name(e).startsWith('.')).toList();

  BrowserPane _activePane = BrowserPane.remote;
  BrowserPane get activePane => _activePane;

  SortField _remoteSortField = SortField.name;
  bool _remoteSortAscending = true;
  bool _remoteShowHidden = false;
  SortField get remoteSortField => _remoteSortField;
  bool get remoteSortAscending => _remoteSortAscending;
  bool get remoteShowHidden => _remoteShowHidden;

  SortField _localSortField = SortField.name;
  bool _localSortAscending = true;
  bool _localShowHidden = false;
  SortField get localSortField => _localSortField;
  bool get localSortAscending => _localSortAscending;
  bool get localShowHidden => _localShowHidden;

  /// Sets [pane]'s sort field, flipping direction instead when it is already
  /// the active field — the same "tap again to reverse" behaviour a desktop
  /// file manager's column headers use, so choosing a field twice is how you
  /// reverse it rather than a dead end.
  void setRemoteSort(SortField field) {
    if (_remoteSortField == field) {
      _remoteSortAscending = !_remoteSortAscending;
    } else {
      _remoteSortField = field;
      _remoteSortAscending = true;
    }
    _notify();
  }

  void setLocalSort(SortField field) {
    if (_localSortField == field) {
      _localSortAscending = !_localSortAscending;
    } else {
      _localSortField = field;
      _localSortAscending = true;
    }
    _notify();
  }

  void toggleRemoteShowHidden() {
    _remoteShowHidden = !_remoteShowHidden;
    _notify();
  }

  void toggleLocalShowHidden() {
    _localShowHidden = !_localShowHidden;
    _notify();
  }

  // --- Multi-select -----------------------------------------------------
  //
  // Checkboxes, not ctrl/shift-click: a file row already answers to a tap
  // (open/download), a long-press and a right-click (the context menu), and
  // this browser runs on touch and desktop from the same widget tree. Adding
  // modifier-key range-select on top would mean a fourth gesture to
  // disambiguate from the other three, correctly, on every platform this
  // ships to — a real feature, not a couple of lines. A checkbox that only
  // appears once selection mode is entered costs one extra tap to start and
  // is unambiguous everywhere, which is the trade this app takes.
  //
  // Selection mode itself is entered from the pane header, not from a
  // long-press on a row: long-press on a row is already spoken for by
  // `ContextMenuRegion` (the per-file action sheet), and a gesture cannot
  // mean two different things on the same widget.

  var _remoteSelectionMode = false;
  var _localSelectionMode = false;
  final Set<String> _remoteSelection = {};
  final Set<String> _localSelection = {};

  bool get remoteSelectionMode => _remoteSelectionMode;
  bool get localSelectionMode => _localSelectionMode;
  Set<String> get remoteSelection => Set.unmodifiable(_remoteSelection);
  Set<String> get localSelection => Set.unmodifiable(_localSelection);

  void toggleRemoteSelectionMode() {
    _remoteSelectionMode = !_remoteSelectionMode;
    if (!_remoteSelectionMode) _remoteSelection.clear();
    _notify();
  }

  void toggleLocalSelectionMode() {
    _localSelectionMode = !_localSelectionMode;
    if (!_localSelectionMode) _localSelection.clear();
    _notify();
  }

  void toggleRemoteSelected(String path) {
    if (!_remoteSelection.remove(path)) _remoteSelection.add(path);
    _notify();
  }

  void toggleLocalSelected(String path) {
    if (!_localSelection.remove(path)) _localSelection.add(path);
    _notify();
  }

  void selectAllRemote() {
    final entries = remoteEntries.value;
    if (entries == null) return;
    _remoteSelection
      ..clear()
      ..addAll(entries.where((e) => !e.isDirectory).map((e) => e.path));
    _notify();
  }

  void selectAllLocal() {
    final entries = localEntries.value;
    if (entries == null) return;
    _localSelection
      ..clear()
      ..addAll(entries.where((e) => !e.isDirectory).map((e) => e.path));
    _notify();
  }

  final List<TransferJob> _transfers = [];
  List<TransferJob> get transfers => List.unmodifiable(_transfers);
  var _transferCounter = 0;

  List<String> get remoteAncestry => _remoteNav.ancestry(_remotePath);

  /// Clamped to [_localBoundary] when sandboxed, so a breadcrumb never
  /// offers a segment above the one directory this pane is allowed to show —
  /// the ancestry list is exactly what `BreadcrumbBar`/`PathBar` render as
  /// tappable, so anything left in it above the boundary would be a way out
  /// of the sandbox that no path-entry validation gets a chance to reject.
  List<String> get localAncestry {
    final full = _localNav.ancestry(_localPath);
    final boundary = _localBoundary;
    if (boundary == null) return full;
    final index = full.indexOf(boundary);
    return index < 0 ? full : full.sublist(index);
  }

  String remoteLabel(String path) => _remoteNav.label(path);
  String localLabel(String path) => _localNav.label(path);
  bool get canGoUpRemote => !_remoteNav.isRoot(_remotePath);
  bool get canGoUpLocal =>
      !_localNav.isRoot(_localPath) && _localPath != _localBoundary;

  void selectPane(BrowserPane pane) {
    if (_activePane == pane) return;
    _activePane = pane;
    _notify();
  }

  Future<void> openRemote(String path) async {
    _remotePath = path;
    await refreshRemote();
  }

  Future<void> upRemote() => openRemote(_remoteNav.up(_remotePath));

  Future<void> refreshRemote() async {
    _remoteEntries = const AsyncValue.loading();
    _notify();
    try {
      final entries = await _sftp.list(_remotePath);
      _remoteEntries = AsyncValue.data(entries);
    } on Object catch (e, st) {
      _remoteEntries = AsyncValue.error(e, st);
    }
    _notify();
  }

  /// Validates and navigates to a path typed into the remote pane's path
  /// field. Absolute or `~`-prefixed input only (see
  /// `BrowsePath.looksNavigable`) — a bare relative fragment is rejected
  /// before this ever reaches the network, since "relative to what" has no
  /// good answer with two panes on screen.
  Future<PathSubmitResult> submitRemotePath(String input) async {
    if (!_remoteNav.looksNavigable(input)) return PathSubmitResult.notAbsolute;
    try {
      final resolved = await _sftp.resolveRemotePath(input.trim());
      final kind = await _sftp.statPath(resolved);
      switch (kind) {
        case RemotePathKind.missing:
          return PathSubmitResult.notFound;
        case RemotePathKind.file:
          return PathSubmitResult.notADirectory;
        case RemotePathKind.directory:
          await openRemote(resolved);
          return PathSubmitResult.ok;
      }
    } on SftpException catch (e) {
      return e.kind == SftpFailureKind.notFound
          ? PathSubmitResult.notFound
          : PathSubmitResult.failed;
    }
  }

  Future<void> openLocal(String path) async {
    _localPath = path;
    await refreshLocal();
  }

  Future<void> upLocal() async {
    // Idempotent at the boundary the same way `BrowsePath.up` is idempotent
    // at the filesystem root — `up()` itself has no notion of the sandbox,
    // so this has to stop it one level early rather than let it compute the
    // real OS parent of the app's own directory.
    if (!canGoUpLocal) return;
    await openLocal(_localNav.up(_localPath));
  }

  Future<void> refreshLocal() async {
    _localEntries = const AsyncValue.loading();
    _notify();
    try {
      final entries = await _localFs.list(_localPath);
      _localEntries = AsyncValue.data(entries);
    } on Object catch (e, st) {
      _localEntries = AsyncValue.error(e, st);
    }
    _notify();
  }

  /// Validates and navigates to a path typed into the local pane's path
  /// field. See [submitRemotePath] for the shared absolute/`~` rule; this
  /// additionally rejects a path outside [_localBoundary] when sandboxed.
  Future<PathSubmitResult> submitLocalPath(String input) async {
    if (!_localNav.looksNavigable(input)) return PathSubmitResult.notAbsolute;
    final resolved = _localFs.resolveLocalPath(input);
    final boundary = _localBoundary;
    if (boundary != null &&
        !_localNav.context.equals(resolved, boundary) &&
        !_localNav.context.isWithin(boundary, resolved)) {
      return PathSubmitResult.outsideSandbox;
    }
    try {
      final kind = await _localFs.statPath(resolved);
      switch (kind) {
        case LocalPathKind.missing:
          return PathSubmitResult.notFound;
        case LocalPathKind.file:
          return PathSubmitResult.notADirectory;
        case LocalPathKind.directory:
          await openLocal(resolved);
          return PathSubmitResult.ok;
      }
    } on Object {
      return PathSubmitResult.failed;
    }
  }

  /// Downloads [entry] into the local pane's current directory.
  ///
  /// Directories are skipped rather than attempted: SFTP has no "download a
  /// tree" primitive, and silently downloading just the one file a user
  /// expected to recurse into would be a worse surprise than doing nothing.
  Future<void> download(RemoteEntry entry) async {
    if (entry.isDirectory) return;
    final localTarget = _localNav.join(_localPath, entry.name);
    final cancelToken = SftpCancelToken();
    final job = _startTransfer(
      name: entry.name,
      direction: TransferDirection.download,
      cancelToken: cancelToken,
    );
    try {
      await _sftp.download(
        remotePath: entry.path,
        localPath: localTarget,
        cancelToken: cancelToken,
        onProgress: (transferred, total) =>
            _updateTransfer(job.id, transferred: transferred, total: total),
      );
      _finishTransfer(job.id);
      await refreshLocal();
    } on SftpCancelledException {
      _finishTransfer(job.id, cancelled: true);
    } on Object catch (e) {
      _finishTransfer(job.id, error: '$e');
    }
  }

  /// Uploads [entry] into the remote pane's current directory.
  Future<void> upload(LocalEntry entry) async {
    if (entry.isDirectory) return;
    final remoteTarget = _remoteNav.join(_remotePath, entry.name);
    final cancelToken = SftpCancelToken();
    final job = _startTransfer(
      name: entry.name,
      direction: TransferDirection.upload,
      cancelToken: cancelToken,
    );
    try {
      await _sftp.upload(
        localPath: entry.path,
        remotePath: remoteTarget,
        cancelToken: cancelToken,
        onProgress: (transferred, total) =>
            _updateTransfer(job.id, transferred: transferred, total: total),
      );
      _finishTransfer(job.id);
      await refreshRemote();
    } on SftpCancelledException {
      _finishTransfer(job.id, cancelled: true);
    } on Object catch (e) {
      _finishTransfer(job.id, error: '$e');
    }
  }

  /// Downloads every selected remote file, one [TransferJob] each, and
  /// leaves selection mode once the batch finishes. A failure on one file
  /// does not stop the rest — `download` already reports each job's outcome
  /// on its own row, so the batch's job here is only to fire all of them,
  /// not to gate one on another.
  Future<void> downloadSelected() async {
    final entries = remoteEntries.value ?? const <RemoteEntry>[];
    final targets = entries.where((e) => _remoteSelection.contains(e.path));
    for (final entry in targets) {
      await download(entry);
    }
    toggleRemoteSelectionMode();
  }

  Future<void> uploadSelected() async {
    final entries = localEntries.value ?? const <LocalEntry>[];
    final targets = entries.where((e) => _localSelection.contains(e.path));
    for (final entry in targets) {
      await upload(entry);
    }
    toggleLocalSelectionMode();
  }

  void cancelTransfer(String id) {
    final index = _transfers.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _transfers[index].cancelToken?.cancel();
  }

  /// Deletes [entry] on the host. The confirmation belongs to the caller —
  /// this runs the deletion, it does not ask permission for it.
  Future<void> deleteRemote(RemoteEntry entry) async {
    await _sftp.delete(entry);
    await refreshRemote();
  }

  Future<void> deleteLocal(LocalEntry entry) async {
    await _localFs.delete(entry);
    await refreshLocal();
  }

  /// Deletes every selected remote entry, collecting failures instead of
  /// stopping at the first one — a batch delete where item 3 of 10 is
  /// read-only should still remove the other nine, and say which one it
  /// could not.
  Future<List<String>> deleteSelectedRemote() async {
    final entries = remoteEntries.value ?? const <RemoteEntry>[];
    final targets = entries.where((e) => _remoteSelection.contains(e.path));
    final failures = <String>[];
    for (final entry in targets) {
      try {
        await _sftp.delete(entry);
      } on Object catch (e) {
        failures.add('${entry.name}: $e');
      }
    }
    await refreshRemote();
    toggleRemoteSelectionMode();
    return failures;
  }

  Future<List<String>> deleteSelectedLocal() async {
    final entries = localEntries.value ?? const <LocalEntry>[];
    final targets = entries.where((e) => _localSelection.contains(e.path));
    final failures = <String>[];
    for (final entry in targets) {
      try {
        await _localFs.delete(entry);
      } on Object catch (e) {
        failures.add('${entry.name}: $e');
      }
    }
    await refreshLocal();
    toggleLocalSelectionMode();
    return failures;
  }

  /// Applies [mode] (the low 9 permission bits — see `domain/permissions.dart`)
  /// to [entry] and refreshes the remote pane so the new `drwx...` string
  /// shows immediately rather than after a manual refresh.
  Future<void> chmodRemote(RemoteEntry entry, int mode) async {
    await _sftp.setPermissions(entry.path, mode);
    await refreshRemote();
  }

  TransferJob _startTransfer({
    required String name,
    required TransferDirection direction,
    SftpCancelToken? cancelToken,
  }) {
    final job = TransferJob(
      id: '${_transferCounter++}',
      name: name,
      direction: direction,
      cancelToken: cancelToken,
    );
    _transfers.add(job);
    _notify();
    return job;
  }

  void _updateTransfer(String id, {required int transferred, int? total}) {
    final index = _transfers.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _transfers[index] = _transfers[index].copyWith(
      transferred: transferred,
      total: total,
    );
    _notify();
  }

  void _finishTransfer(String id, {String? error, bool cancelled = false}) {
    final index = _transfers.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _transfers[index] = _transfers[index].copyWith(
      done: true,
      error: error,
      cancelled: cancelled,
    );
    _notify();
  }

  void _notify() {
    // `refreshRemote`/`refreshLocal` run during construction, before any
    // listener can exist, and can still be in flight when the screen that
    // owns this controller is popped — notifying a disposed ChangeNotifier
    // throws, same reasoning as `TerminalSession._disposed`.
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sftp.close());
    super.dispose();
  }
}
