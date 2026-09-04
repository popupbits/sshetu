import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:picons/picons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/feedback.dart';
import '../../../core/ui/views.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/transfer_payload.dart';
import '../transfer_providers.dart';
import '../transfer_session.dart';

/// Shows the code, and holds the listener open exactly as long as it is shown.
///
/// The screen owns the socket. Leaving closes it — there is no way to end up
/// with a port open and nothing on screen saying so, which is the property
/// that makes this safe to offer at all.
class TransferSendScreen extends ConsumerStatefulWidget {
  const TransferSendScreen({this.embedded = false, super.key});

  /// True when this is a tab in the desktop workspace, which draws its own
  /// tab and close button — a second app bar inside it would be chrome
  /// repeating itself.
  final bool embedded;

  @override
  ConsumerState<TransferSendScreen> createState() => _TransferSendScreenState();
}

class _TransferSendScreenState extends ConsumerState<TransferSendScreen> {
  TransferSender? _sender;
  String? _sentTo;
  String? _error;

  /// Which part of starting is currently taking time, so the wait can name
  /// itself instead of being one spinner that covers everything.
  TransferStartStep? _step;

  /// Off by default. Sending key material is the most dangerous thing this app
  /// does, and it should take a deliberate tap rather than being the path of
  /// least resistance.
  var _includeSecrets = false;
  var _starting = true;

  /// Which restart is current.
  ///
  /// Toggling the switch closes the previous sender, and closing it completes
  /// that sender's `handOver` with "cancelled" — correct for a real cancel,
  /// and wrong to show here, because by then a new session is already on
  /// screen. Without this, flipping the switch replaced the fresh QR code with
  /// the previous session's cancellation.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restart());
  }

  @override
  void dispose() {
    unawaited(_sender?.close());
    super.dispose();
  }

  /// Builds a payload and opens a listener for it.
  ///
  /// Restarted when the secrets switch moves, because the offer the other
  /// device sees has to match what it will actually get — and a code already
  /// scanned under the old answer must not deliver the new one.
  Future<void> _restart() async {
    final generation = ++_generation;
    await _sender?.close();
    if (!mounted || generation != _generation) return;
    setState(() {
      _starting = true;
      _error = null;
      _sentTo = null;
      _sender = null;
      _step = null;
    });

    try {
      final database = ref.read(databaseProvider);
      final payload = await TransferPayload.read(
        database.raw,
        vault: ref.read(secretVaultProvider),
        includeSecrets: _includeSecrets,
      );
      final sender = await TransferSender.start(
        payload: payload,
        deviceName: await _deviceName(),
        clearToListen: ref.read(listenPermissionProvider),
        onStep: (step) {
          if (!mounted || generation != _generation) return;
          setState(() => _step = step);
        },
      );
      if (!mounted || generation != _generation) {
        await sender.close();
        return;
      }
      setState(() {
        _sender = sender;
        _starting = false;
      });

      final receiver = await sender.handOver();
      if (!mounted || generation != _generation) return;
      setState(() => _sentTo = receiver);
    } on Object catch (error) {
      // A superseded session's failure is not this session's news.
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error is TransferException ? error.message : '$error';
        _starting = false;
        _step = null;
      });
    }
  }

  /// Abandons a start that is waiting on something outside the app.
  ///
  /// Bumping the generation is what makes this immediate: the pending start is
  /// now superseded, so whatever it eventually returns lands on the floor.
  void _cancelStart() {
    _generation++;
    unawaited(_sender?.close());
    setState(() {
      _sender = null;
      _starting = false;
      _step = null;
      _error = AppLocalizations.of(context).transferNotStarted;
    });
  }

  /// What the other device calls this one. The hostname, because on a laptop
  /// that is already the name its owner chose.
  static Future<String> _deviceName() async => Platform.localHostname;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final body = ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(Spacing.xl),
        children: [
          Text(l10n.transferSendTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.transferSendBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // The firewall prompt is a system modal that can open behind the
          // window or on another Space, and until it is answered nothing can
          // reach this device — which reads as the app having frozen. Say so
          // before it happens rather than leaving someone guessing.
          if (Platform.isMacOS) ...[
            const SizedBox(height: Spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PiconsRegular.info,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    l10n.transferFirewallNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.xl),
          _Code(
            sender: _sender,
            starting: _starting,
            step: _step,
            error: _error,
            sentTo: _sentTo,
            onRetry: _restart,
            onCancel: _cancelStart,
          ),
          const SizedBox(height: Spacing.xl),
          SwitchListTile(
            value: _includeSecrets,
            // Locked once a device has taken the payload: the switch would
            // otherwise look like it still governed something.
            onChanged: _sentTo != null
                ? null
                : (value) {
                    setState(() => _includeSecrets = value);
                    unawaited(_restart());
                  },
            title: Text(l10n.transferIncludeSecrets),
            subtitle: Text(l10n.transferIncludeSecretsBody),
            secondary: Icon(
              _includeSecrets ? PiconsRegular.key : PiconsRegular.keyhole,
              color: _includeSecrets ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );

    // Embedded in the workspace, the tab is the title and the tab's close
    // button is the way out; a Scaffold here would stack a second app bar
    // inside a pane that already has one above it.
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferSend)),
      body: body,
    );
  }
}

/// The QR itself, or whatever is true instead of it.
class _Code extends StatelessWidget {
  const _Code({
    required this.sender,
    required this.starting,
    required this.step,
    required this.error,
    required this.sentTo,
    required this.onRetry,
    required this.onCancel,
  });

  final TransferSender? sender;
  final bool starting;
  final TransferStartStep? step;
  final String? error;
  final String? sentTo;
  final Future<void> Function() onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (sentTo case final device?) {
      return _Result(
        icon: PiconsRegular.checkCircle,
        color: theme.colorScheme.primary,
        message: l10n.transferSentTo(device),
      );
    }
    if (error case final message?) {
      return _Result(
        icon: PiconsRegular.warning,
        color: theme.colorScheme.error,
        message: message,
        action: FilledButton(
          onPressed: () => unawaited(onRetry()),
          child: Text(l10n.actionRetry),
        ),
      );
    }
    if (starting || sender == null) {
      // Named, and with a way out. Waiting on a system permission dialog can
      // take as long as it takes someone to find it, and a wait nobody can
      // abandon is how a screen comes to look broken.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
        child: Column(
          children: [
            const LoadingView(),
            const SizedBox(height: Spacing.lg),
            Text(
              switch (step) {
                TransferStartStep.permission => l10n.transferStepPermission,
                TransferStartStep.binding => l10n.transferStepBinding,
                null => l10n.transferStepBinding,
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextButton(onPressed: onCancel, child: Text(l10n.transferCancel)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // White quiet zone regardless of theme: a scanner reads dark-on-light,
        // and a QR rendered in theme colours on a dark ground is a QR that
        // does not scan.
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: QrImageView(
            data: sender!.code.encode(),
            version: QrVersions.auto,
            size: 260,
            backgroundColor: Colors.white,
            // Errors drawn rather than thrown: a code too dense to encode
            // should not take the screen down with it.
            errorStateBuilder: (context, _) => SizedBox(
              width: 260,
              height: 260,
              child: Center(child: Text(l10n.actionRetry)),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              l10n.transferWaiting,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        // The address is worth showing: it is how someone diagnoses "the other
        // device cannot see me" without any tooling.
        Text(
          '${sender!.code.addresses.first}:${sender!.code.port}',
          style: Mono.apply(theme.textTheme.labelSmall)
              .copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Spacing.md),
        // Desktop to desktop has no camera on either end. The same code as
        // text covers that, and covers a phone whose camera permission was
        // declined — the receiving screen already takes a pasted code.
        //
        // It carries the secret, so it goes to the clipboard on a deliberate
        // tap and is never rendered on screen.
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: sender!.code.encode()));
            if (context.mounted) context.toast(l10n.transferCodeCopied);
          },
          icon: const Icon(PiconsRegular.copy, size: 16),
          label: Text(l10n.transferCopyCode),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.icon,
    required this.color,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
    child: Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: Spacing.lg),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (action case final widget?) ...[
          const SizedBox(height: Spacing.lg),
          widget,
        ],
      ],
    ),
  );
}
