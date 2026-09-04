import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:picons/picons.dart';

import '../../../core/db/database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../hosts/hosts_controller.dart';
import '../../keys/keys_controller.dart';
import '../../tunnels/tunnels_controller.dart';
import '../domain/pairing_code.dart';
import '../transfer_session.dart';

/// Scans a code, shows what is on offer, and applies it only if asked.
///
/// The camera is a convenience, not a requirement: a code can be pasted as
/// text instead. That is what makes this work on a desktop with no camera, on
/// a device where the permission was refused, and in a test.
class TransferReceiveScreen extends ConsumerStatefulWidget {
  const TransferReceiveScreen({this.embedded = false, super.key});

  /// True when this is a tab in the desktop workspace, which draws its own
  /// tab and close button — a second app bar inside it would be chrome
  /// repeating itself.
  final bool embedded;

  @override
  ConsumerState<TransferReceiveScreen> createState() =>
      _TransferReceiveScreenState();
}

class _TransferReceiveScreenState extends ConsumerState<TransferReceiveScreen> {
  /// Created when the user asks to scan, not before.
  ///
  /// Constructing it starts the camera, which on Android means the permission
  /// sheet appears the instant this screen opens — before the user has done
  /// anything, with no explanation, over a black rectangle. A permission
  /// request has to follow a request *from the user*, or it reads as the app
  /// grabbing for the camera.
  MobileScannerController? _controller;
  final _pasted = TextEditingController();

  /// True from the first accepted code until the screen is done with it, so a
  /// camera firing ten frames a second cannot start ten transfers.
  var _busy = false;
  String? _error;
  int? _received;

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _pasted.dispose();
    super.dispose();
  }

  void _startScanning() => setState(() {
    _error = null;
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  });

  Future<void> _stopScanning() async {
    final controller = _controller;
    setState(() => _controller = null);
    await controller?.dispose();
  }

  Future<void> _onCode(String raw) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    TransferReceiver? session;
    try {
      final code = PairingCode.decode(raw);
      await _controller?.stop();

      session = await TransferReceiver.connect(
        code,
        deviceName: Platform.localHostname,
      );
      if (!mounted) {
        await session.close();
        return;
      }

      // The boundary: nothing is written until this returns true.
      final accepted = await _confirm(session.offer);
      if (!accepted) {
        await session.close();
        if (mounted) setState(() => _busy = false);
        unawaited(_controller?.start());
        return;
      }

      final payload = await session.accept();
      await payload.apply(
        ref.read(databaseProvider).raw,
        vault: ref.read(secretVaultProvider),
      );

      // The lists are read-through providers; nothing else tells them a whole
      // configuration just landed underneath them.
      ref
        ..invalidate(hostsProvider)
        ..invalidate(identitiesProvider)
        ..invalidate(tunnelsProvider);

      if (mounted) setState(() => _received = payload.hostCount);
    } on Object catch (error) {
      await session?.close();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = switch (error) {
            PairingCodeException(:final message) => message,
            TransferException(:final message) => message,
            _ => '$error',
          };
        });
      }
      unawaited(_controller?.start());
    }
  }

  /// Everything the sender is offering, in as many words, before anything is
  /// written. Returns whether the user said yes.
  Future<bool> _confirm(TransferOffer offer) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(PiconsRegular.downloadSimple),
        title: Text(l10n.transferOfferTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.transferOfferFrom(offer.deviceName)),
            const SizedBox(height: Spacing.md),
            Text(l10n.transferOfferHosts(offer.hosts)),
            Text(l10n.transferOfferKeys(offer.identities)),
            Text(l10n.transferOfferTunnels(offer.tunnels)),
            Text(l10n.transferOfferTrusted(offer.knownHosts)),
            const SizedBox(height: Spacing.md),
            // The line that matters. Coloured and iconned because it is the
            // difference between copying a list of addresses and copying the
            // keys to every machine on it.
            Row(
              children: [
                Icon(
                  offer.includesSecrets
                      ? PiconsRegular.key
                      : PiconsRegular.keyhole,
                  size: 16,
                  color: offer.includesSecrets
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    offer.includesSecrets
                        ? l10n.transferOfferSecrets
                        : l10n.transferOfferNoSecrets,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: offer.includesSecrets
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(
              l10n.transferOfferReplaces,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.transferAccept),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final body = ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(Spacing.xl),
        children: [
          if (_received case final count?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
              child: Column(
                children: [
                  Icon(
                    PiconsRegular.checkCircle,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    l10n.transferReceived(count),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              l10n.transferReceiveBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            if (_supportsCamera)
              if (_controller case final controller?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: SizedBox(
                    height: 280,
                    child: MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final value = capture.barcodes.firstOrNull?.rawValue;
                        if (value != null) unawaited(_onCode(value));
                      },
                      errorBuilder: (context, error) => _CameraUnavailable(
                        message: l10n.transferCameraDenied,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => unawaited(_stopScanning()),
                    child: Text(l10n.actionCancel),
                  ),
                ),
              ] else
                // The camera opens on a tap, never on arrival: a permission
                // sheet the user did not ask for, over a black rectangle,
                // reads as the app grabbing for their camera.
                FilledButton.icon(
                  onPressed: _startScanning,
                  icon: const Icon(PiconsRegular.qrCode),
                  label: Text(l10n.transferScanCode),
                ),
            if (_error case final message?) ...[
              const SizedBox(height: Spacing.lg),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: Spacing.xl),
            // Always present, not a fallback behind a failure: it is the
            // only way in on a desktop with no camera, and hiding it until
            // something goes wrong helps nobody.
            Text(l10n.transferPasteInstead, style: theme.textTheme.labelLarge),
            const SizedBox(height: Spacing.sm),
            // Side by side while there is room, stacked when there is not.
            // A button cannot shrink below its own label, so a Row here
            // overflowed by eighty points as soon as this became a tab in a
            // pane someone could drag narrow.
            LayoutBuilder(
              builder: (context, constraints) {
                final field = TextField(
                  controller: _pasted,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: l10n.transferPasteHint,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (value) => unawaited(_onCode(value)),
                );
                final button = FilledButton(
                  onPressed: _busy
                      ? null
                      : () => unawaited(_onCode(_pasted.text)),
                  child: Text(l10n.transferReceive),
                );

                if (constraints.maxWidth < 380) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      field,
                      const SizedBox(height: Spacing.sm),
                      button,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: Spacing.sm),
                    button,
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );

    // Embedded in the workspace, the tab is the title and the tab's close
    // button is the way out; a Scaffold here would stack a second app bar
    // inside a pane that already has one above it.
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferReceive)),
      body: body,
    );
  }

  /// Whether this platform has a scanner at all. Windows and Linux do not, and
  /// they reach the same feature through the paste field.
  static bool get _supportsCamera =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
