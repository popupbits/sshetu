import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/appwrite/failures.dart';
import '../../core/router/navigation.dart';
import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/feedback.dart';
import '../../core/util/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'auth_controller.dart';
import 'auth_validators.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscured = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(email: _email.text.trim(), password: _password.text);
      // The router's redirect takes it from here; nothing to navigate to.
    } on AppwriteFailure catch (e) {
      if (mounted) context.toast(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      // Sign-in used to be the app's gate, so it needed no way out. It is
      // optional now — everything works without an account, and this is
      // reached by choice from Settings — which made a screen with no back
      // button a trap you could only leave by quitting.
      //
      // `AppBar()` alone is right: automaticallyImplyLeading shows the back
      // arrow exactly when there is somewhere to go back to, so this stays
      // correct if sign-in is ever the first screen again.
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.xl),
            child: ContentWidth(
              maxWidth: 420,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: Spacing.xxl),
                    TextFormField(
                      controller: _email,
                      decoration: InputDecoration(labelText: l10n.authEmail),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (value) => validateEmail(value, l10n),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: l10n.authPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscured = !_obscured),
                        ),
                      ),
                      obscureText: _obscured,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      // Only "did you type one" on sign-in: length rules
                      // belong on sign-up, where they change the outcome.
                      validator: (value) =>
                          validatePasswordPresent(value, l10n),
                    ),
                    const SizedBox(height: Spacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.authSignIn),
                    ),
                    const SizedBox(height: Spacing.md),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.goTo(Routes.signUp),
                      child: Text(l10n.authNoAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
