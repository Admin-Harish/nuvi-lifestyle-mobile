/// Sign in.
///
/// The screen shows **one** error message for every rejected sign-in, taken
/// from [Session]. It never renders the server's `detail` for a credential
/// failure and never marks one field invalid rather than the other: "we don't
/// know that email" and "wrong password" must be indistinguishable in the UI
/// exactly as they are in the API, or the enumeration protection stops at the
/// network boundary.
library;

import 'package:flutter/material.dart';

import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import 'register_screen.dart';
import 'session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.session, super.key});

  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.session.signIn(
      email: _email.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final session = widget.session;
        return NuviPage(
          title: 'Sign in',
          children: [
            Text(
              'Nuvi Lifestyle',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: NuviSpacing.xl),
            if (session.error != null)
              NuviNotice(message: session.error!, icon: Icons.error_outline),
            NuviField(
              key: const Key('login-email'),
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            NuviField(
              key: const Key('login-password'),
              label: 'Password',
              controller: _password,
              obscure: true,
              autofillHints: const [AutofillHints.password],
            ),
            NuviPrimaryButton(
              key: const Key('login-submit'),
              label: 'Sign in',
              busy: session.isBusy,
              onPressed: _submit,
            ),
            const SizedBox(height: NuviSpacing.lg),
            TextButton(
              key: const Key('login-forgot'),
              onPressed: session.isBusy
                  ? null
                  : () => _requestReset(context, session),
              child: const Text('I forgot my password'),
            ),
            TextButton(
              key: const Key('login-register'),
              onPressed: session.isBusy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RegisterScreen(session: session),
                      ),
                    ),
              child: const Text('Create an account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestReset(BuildContext context, Session session) async {
    final messenger = ScaffoldMessenger.of(context);
    await session.requestPasswordReset(email: _email.text.trim());
    if (!mounted) return;
    // Deliberately unconditional: the server reports nothing about whether the
    // address exists, so neither does this. Showing "sent" only for real
    // addresses would undo the whole design.
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'If that address can be used, we have sent a reset code to it.',
        ),
      ),
    );
  }
}
