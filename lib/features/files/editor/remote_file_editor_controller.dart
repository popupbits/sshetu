import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/widgets.dart'
    show TextEditingController, TextEditingValue, TextSelection;

import '../../../core/ssh/sftp_service.dart';
import '../domain/atomic_save.dart';
import '../domain/text_document.dart';

/// Where the editor is: loading, refused, or holding a file.
enum EditorStatus { loading, ready, failed }

/// Why a file would not open. [message] is set for [EditorLoadError.sftp],
/// which carries the server's own reason.
enum EditorLoadError { tooLarge, binary, notUtf8, notAFile, sftp }

/// What to do when the file changed on the server since it was loaded.
enum SaveConflictChoice { overwrite, reload, cancel }

/// Asked, before a save, when the file on the server is not the one that was
/// loaded. The UI answers with a dialog.
typedef SaveConflictResolver = Future<SaveConflictChoice> Function();

/// How a [RemoteFileEditorController.save] call ended.
enum SaveOutcome {
  /// Written. [RemoteFileEditorController.lastSaveMethod] says how.
  saved,

  /// Nothing to save.
  unchanged,

  /// The user chose to reload the server's version instead.
  reloaded,

  /// The user backed out of the conflict.
  cancelled,

  /// The write failed; [RemoteFileEditorController.saveError] says why.
  failed,
}

/// One remote text file open for editing.
///
/// Holds the loaded bytes' shape ([TextDocument]: line endings, BOM), the
/// stat taken at load (to notice the file changing underneath), and the text
/// being edited. A plain [ChangeNotifier] like `FileBrowserController`, and
/// for the same reason: it wraps one SFTP channel for one open thing.
///
/// Owns [sftp] and closes it on [dispose] when [ownsSftp] is true — an editor
/// tab outlives the file browser it was opened from, so it has a channel of
/// its own rather than borrowing one that closes with the browser.
class RemoteFileEditorController extends ChangeNotifier {
  RemoteFileEditorController({
    required this.sftp,
    required this.path,
    this.maxBytes = kMaxEditableBytes,
    this.ownsSftp = true,
  }) {
    text.addListener(_onTextChanged);
  }

  final SftpService sftp;
  final String path;
  final int maxBytes;
  final bool ownsSftp;

  /// The text being edited. Owned here, not by the widget, so the edit
  /// survives the editor being rebuilt — a desktop tab switched away from
  /// and back again.
  final TextEditingController text = TextEditingController();

  EditorStatus _status = EditorStatus.loading;
  EditorStatus get status => _status;

  EditorLoadError? _loadError;
  EditorLoadError? get loadError => _loadError;

  String? _loadMessage;
  String? get loadMessage => _loadMessage;

  TextDocument? _document;
  TextDocument? get document => _document;

  RemoteFileStat? _loadedStat;

  String _savedText = '';

  bool _dirty = false;

  /// Whether the text differs from what was loaded or last saved.
  bool get isDirty => _dirty;

  bool _saving = false;
  bool get isSaving => _saving;

  String? _saveError;
  String? get saveError => _saveError;

  SaveMethod? _lastSaveMethod;
  SaveMethod? get lastSaveMethod => _lastSaveMethod;

  bool _disposed = false;

  String get name {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  /// Reads the file from the server. Also what "reload" does.
  Future<void> load() async {
    _status = EditorStatus.loading;
    _loadError = null;
    _loadMessage = null;
    _notify();
    try {
      final stat = await sftp.stat(path);
      if (stat.isDirectory) return _fail(EditorLoadError.notAFile);
      if ((stat.size ?? 0) > maxBytes) return _fail(EditorLoadError.tooLarge);

      final bytes = await sftp.readFile(path, maxBytes: maxBytes);
      final decoded = TextDocument.decode(bytes);
      final document = decoded.document;
      if (document == null) {
        return _fail(switch (decoded.failure!) {
          TextDecodeFailure.binary => EditorLoadError.binary,
          TextDecodeFailure.notUtf8 => EditorLoadError.notUtf8,
        });
      }
      _document = document;
      _loadedStat = stat;
      _savedText = document.text;
      _setText(document.text);
      _dirty = false;
      _saveError = null;
      _status = EditorStatus.ready;
      _notify();
    } on SftpException catch (e) {
      _loadMessage = e.message;
      _fail(EditorLoadError.sftp);
    }
  }

  void _fail(EditorLoadError error) {
    _loadError = error;
    _status = EditorStatus.failed;
    _notify();
  }

  /// Puts back the text as it was loaded or last saved, without asking the
  /// server anything.
  void revert() {
    if (_document == null) return;
    _setText(_savedText);
  }

  /// Saves the edited text.
  ///
  /// Re-stats first: when the file's size or modification time differs from
  /// what was loaded, somebody else changed it, and [onConflict] decides —
  /// overwrite their change, reload theirs (discarding these edits), or
  /// cancel. Without a resolver a conflict cancels, the choice that cannot
  /// destroy anyone's work.
  Future<SaveOutcome> save({SaveConflictResolver? onConflict}) async {
    final document = _document;
    final loaded = _loadedStat;
    if (document == null || loaded == null || _saving) {
      return SaveOutcome.unchanged;
    }
    _saving = true;
    _saveError = null;
    _notify();
    try {
      final RemoteFileStat current;
      try {
        current = await sftp.stat(path);
      } on SftpException catch (e) {
        // Deleted since it was opened: writing it back recreates it, which
        // is what someone pressing Save means. Anything else is a failure.
        if (e.kind != SftpFailureKind.notFound) rethrow;
        return await _write(document, loaded);
      }
      if (_changedSince(loaded, current)) {
        final choice =
            await (onConflict?.call() ??
                Future.value(SaveConflictChoice.cancel));
        switch (choice) {
          case SaveConflictChoice.cancel:
            return SaveOutcome.cancelled;
          case SaveConflictChoice.reload:
            _saving = false;
            await load();
            return SaveOutcome.reloaded;
          case SaveConflictChoice.overwrite:
            break;
        }
      }
      return await _write(document, current);
    } on SftpException catch (e) {
      _saveError = e.message;
      return SaveOutcome.failed;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<SaveOutcome> _write(TextDocument document, RemoteFileStat base) async {
    final edited = text.text;
    _lastSaveMethod = await saveRemoteFile(
      sftp,
      path,
      document.encode(edited),
      original: base,
    );
    _savedText = edited;
    _dirty = false;
    // What is on the server now is what the next conflict check compares
    // against. If this stat fails the save still happened; the next save
    // will simply ask about a conflict that is really this one.
    try {
      _loadedStat = await sftp.stat(path);
    } on SftpException {
      _loadedStat = base;
    }
    return SaveOutcome.saved;
  }

  static bool _changedSince(RemoteFileStat loaded, RemoteFileStat current) =>
      loaded.size != current.size || loaded.modified != current.modified;

  void _setText(String value) {
    text.value = TextEditingValue(
      text: value,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _onTextChanged() {
    final dirty = text.text != _savedText;
    if (dirty == _dirty) return;
    _dirty = dirty;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    text
      ..removeListener(_onTextChanged)
      ..dispose();
    if (ownsSftp) unawaited(sftp.close());
    super.dispose();
  }
}
