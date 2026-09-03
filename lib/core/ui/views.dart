import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../util/responsive.dart';

/// Centred spinner. A named widget rather than a bare
/// `CircularProgressIndicator` so every loading state has the same padding
/// and can be restyled in one place.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(Spacing.xxl),
      child: CircularProgressIndicator(),
    ),
  );
}

/// "There is nothing here yet" — with the action that would change that.
///
/// [action] is what makes this worth a widget: an empty state without a way
/// out is a dead end, and having the parameter present makes its absence a
/// deliberate choice rather than an oversight.
///
/// Capped at [Breakpoints.maxMessageWidth]: without it the message becomes one
/// very long line on a desktop window instead of a readable column.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ContentWidth(
        maxWidth: Breakpoints.maxMessageWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: Spacing.lg),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Spacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Something went wrong, with a way to try again.
///
/// Width-capped for the same reason as [EmptyView].
class ErrorView extends StatelessWidget {
  const ErrorView({
    required this.message,
    this.onRetry,
    this.retryLabel,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scrollable, not padded: the message is whatever the failure produced,
    // and some of them are long — a Riverpod error carries its provider chain,
    // a platform exception its own prose. An error view that overflows while
    // reporting an error is the worst possible time to run out of room, and
    // on a short phone screen it happens with very ordinary messages.
    return Center(
      child: ContentWidth(
        maxWidth: Breakpoints.maxMessageWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: Spacing.xl),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(retryLabel ?? 'Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small uppercase label above a group of rows.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xl,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
