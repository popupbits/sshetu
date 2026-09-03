import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue;
import 'package:path/path.dart' as p;

import '../../core/ssh/sftp_service.dart';
import 'data/local_fs_service.dart';
import 'domain/browse_path.dart';

/// Which side of the dual-pane browser is showing on a phone, where there is
/// only room for one at a time.
enum BrowserPane { remote, local }

enum TransferDirection { download, upload }

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

  /// True once the transfer has finished, successfully or not.
  final bool done;

  bool get failed => error != null;

  TransferJob copyWith({
    int? transferred,
    int? total,
    String? error,
    bool? done,
  }) => TransferJob(
    id: id,
    name: name,
    direction: direction,
    total: total ?? this.total,
    transferred: transferred ?? this.transferred,
    error: error ?? this.error,
    done: done ?? this.done,
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
       _localPath = localRoot {
    unawaited(refreshRemote());
    unawaited(refreshLocal());
  }

  final SftpService _sftp;
  final LocalFsService _localFs;
  final BrowsePath _remoteNav;
  final BrowsePath _localNav;

  bool _disposed = false;

  String _remotePath;
  String get remotePath => _remotePath;

  String _localPath;
  String get localPath => _localPath;

  AsyncValue<List<RemoteEntry>> _remoteEntries = const AsyncValue.loading();
  AsyncValue<List<RemoteEntry>> get remoteEntries => _remoteEntries;

  AsyncValue<List<LocalEntry>> _localEntries = const AsyncValue.loading();
  AsyncValue<List<LocalEntry>> get localEntries => _localEntries;

  BrowserPane _activePane = BrowserPane.remote;
  BrowserPane get activePane => _activePane;

  final List<TransferJob> _transfers = [];
  List<TransferJob> get transfers => List.unmodifiable(_transfers);
  var _transferCounter = 0;

  List<String> get remoteAncestry => _remoteNav.ancestry(_remotePath);
  List<String> get localAncestry => _localNav.ancestry(_localPath);
  String remoteLabel(String path) => _remoteNav.label(path);
  String localLabel(String path) => _localNav.label(path);
  bool get canGoUpRemote => !_remoteNav.isRoot(_remotePath);
  bool get canGoUpLocal => !_localNav.isRoot(_localPath);

  void selectPane(BrowserPane pane) {
    if (_activePane == pane) return;
    _activePane = pane;
    notifyListeners();
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

  Future<void> openLocal(String path) async {
    _localPath = path;
    await refreshLocal();
  }

  Future<void> upLocal() => openLocal(_localNav.up(_localPath));

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

  /// Downloads [entry] into the local pane's current directory.
  ///
  /// Directories are skipped rather than attempted: SFTP has no "download a
  /// tree" primitive, and silently downloading just the one file a user
  /// expected to recurse into would be a worse surprise than doing nothing.
  Future<void> download(RemoteEntry entry) async {
    if (entry.isDirectory) return;
    final localTarget = _localNav.join(_localPath, entry.name);
    final job = _startTransfer(
      name: entry.name,
      direction: TransferDirection.download,
    );
    try {
      await _sftp.download(
        remotePath: entry.path,
        localPath: localTarget,
        onProgress: (transferred, total) =>
            _updateTransfer(job.id, transferred: transferred, total: total),
      );
      _finishTransfer(job.id);
      await refreshLocal();
    } on Object catch (e) {
      _finishTransfer(job.id, error: '$e');
    }
  }

  /// Uploads [entry] into the remote pane's current directory.
  Future<void> upload(LocalEntry entry) async {
    if (entry.isDirectory) return;
    final remoteTarget = _remoteNav.join(_remotePath, entry.name);
    final job = _startTransfer(
      name: entry.name,
      direction: TransferDirection.upload,
    );
    try {
      await _sftp.upload(
        localPath: entry.path,
        remotePath: remoteTarget,
        onProgress: (transferred, total) =>
            _updateTransfer(job.id, transferred: transferred, total: total),
      );
      _finishTransfer(job.id);
      await refreshRemote();
    } on Object catch (e) {
      _finishTransfer(job.id, error: '$e');
    }
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

  TransferJob _startTransfer({
    required String name,
    required TransferDirection direction,
  }) {
    final job = TransferJob(
      id: '${_transferCounter++}',
      name: name,
      direction: direction,
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

  void _finishTransfer(String id, {String? error}) {
    final index = _transfers.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _transfers[index] = _transfers[index].copyWith(done: true, error: error);
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
