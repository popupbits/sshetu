import 'package:material_ui/material_ui.dart';

import '../../../core/theme/terminal_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/permissions.dart';

/// A checkbox grid for user/group/other × read/write/execute, plus the
/// octal string the same nine bits also are — editable both ways, since
/// people who reach for `chmod` think in either notation depending on the
/// day and neither should be the "advanced" one hidden behind the other.
///
/// Returns the new mode via [Navigator.pop] when applied, or null when
/// cancelled — the caller decides what "apply" means (a `setPermissions`
/// call plus a refresh), this widget only decides what mode was chosen.
class ChmodDialog extends StatefulWidget {
  const ChmodDialog({required this.initialMode, super.key});

  final int initialMode;

  static Future<int?> show(BuildContext context, int initialMode) =>
      showDialog<int>(
        context: context,
        builder: (context) => ChmodDialog(initialMode: initialMode),
      );

  @override
  State<ChmodDialog> createState() => _ChmodDialogState();
}

class _ChmodDialogState extends State<ChmodDialog> {
  late var _bits = PermissionBits.fromMode(widget.initialMode);
  late final _octalController = TextEditingController(text: _bits.octal);
  String? _octalError;

  @override
  void dispose() {
    _octalController.dispose();
    super.dispose();
  }

  void _setBits(PermissionBits next) {
    setState(() {
      _bits = next;
      _octalError = null;
      // The checkbox grid is the source of truth here; the octal field just
      // mirrors it. Only overwritten when it does not already show the same
      // value, so a checkbox toggle mid-edit does not clobber cursor
      // position for no reason.
      if (_octalController.text != next.octal) {
        _octalController.text = next.octal;
      }
    });
  }

  void _onOctalChanged(String value) {
    final parsed = parseOctalPermissions(value);
    setState(() {
      if (parsed == null) {
        _octalError = AppLocalizations.of(context).filesChmodOctalInvalid;
      } else {
        _bits = parsed;
        _octalError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.filesChmod),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PermissionTriadHeader(l10n: l10n),
            _PermissionTriadRow(
              label: l10n.filesChmodOwner,
              read: _bits.ownerRead,
              write: _bits.ownerWrite,
              execute: _bits.ownerExecute,
              onChanged: (read, write, execute) => _setBits(
                _bits.copyWith(
                  ownerRead: read,
                  ownerWrite: write,
                  ownerExecute: execute,
                ),
              ),
            ),
            _PermissionTriadRow(
              label: l10n.filesChmodGroup,
              read: _bits.groupRead,
              write: _bits.groupWrite,
              execute: _bits.groupExecute,
              onChanged: (read, write, execute) => _setBits(
                _bits.copyWith(
                  groupRead: read,
                  groupWrite: write,
                  groupExecute: execute,
                ),
              ),
            ),
            _PermissionTriadRow(
              label: l10n.filesChmodOther,
              read: _bits.otherRead,
              write: _bits.otherWrite,
              execute: _bits.otherExecute,
              onChanged: (read, write, execute) => _setBits(
                _bits.copyWith(
                  otherRead: read,
                  otherWrite: write,
                  otherExecute: execute,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _octalController,
              onChanged: _onOctalChanged,
              style: Mono.apply(theme.textTheme.bodyLarge),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.filesChmodOctalLabel,
                errorText: _octalError,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _octalError == null
              ? () => Navigator.of(context).pop(_bits.value)
              : null,
          child: Text(l10n.filesChmodApply),
        ),
      ],
    );
  }
}

class _PermissionTriadHeader extends StatelessWidget {
  const _PermissionTriadHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        children: [
          const Expanded(flex: 2, child: SizedBox()),
          Expanded(
            child: Center(child: Text(l10n.filesChmodRead, style: style)),
          ),
          Expanded(
            child: Center(child: Text(l10n.filesChmodWrite, style: style)),
          ),
          Expanded(
            child: Center(child: Text(l10n.filesChmodExecute, style: style)),
          ),
        ],
      ),
    );
  }
}

class _PermissionTriadRow extends StatelessWidget {
  const _PermissionTriadRow({
    required this.label,
    required this.read,
    required this.write,
    required this.execute,
    required this.onChanged,
  });

  final String label;
  final bool read;
  final bool write;
  final bool execute;
  final void Function(bool read, bool write, bool execute) onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(flex: 2, child: Text(label)),
      Expanded(
        child: Checkbox(
          value: read,
          onChanged: (v) => onChanged(v ?? false, write, execute),
        ),
      ),
      Expanded(
        child: Checkbox(
          value: write,
          onChanged: (v) => onChanged(read, v ?? false, execute),
        ),
      ),
      Expanded(
        child: Checkbox(
          value: execute,
          onChanged: (v) => onChanged(read, write, v ?? false),
        ),
      ),
    ],
  );
}
