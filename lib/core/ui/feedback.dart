import 'package:material_ui/material_ui.dart';

/// Snackbars and confirmations, as context extensions.
///
/// Both guard on `mounted` internally where they can, because the overwhelming
/// majority of call sites are `await`-then-show and would otherwise need the
/// same three-line dance every time.
extension FeedbackContext on BuildContext {
  /// Show a transient message. [isError] colours it with the error scheme.
  void toast(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    final scheme = Theme.of(this).colorScheme;
    messenger
      // One message at a time; a queue of stale snackbars helps nobody.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? scheme.errorContainer : null,
          showCloseIcon: isError,
        ),
      );
  }

  /// Ask before doing something destructive.
  ///
  /// Returns false when dismissed, so a barrier tap is never a yes.
  Future<bool> confirm({
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final scheme = Theme.of(this).colorScheme;
    final result = await showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
