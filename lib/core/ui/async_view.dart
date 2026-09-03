import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'views.dart';

/// Renders an [AsyncValue]'s three states without repeating the switch on
/// every screen.
///
/// Keeps the previous data visible while a refresh is in flight, so pulling to
/// refresh does not blank the list — [AsyncValue.isLoading] with existing data
/// is a refresh, not a first load.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const LoadingView(),
      error: (error, _) =>
          ErrorView(message: error.toString(), onRetry: onRetry),
    );
  }
}
