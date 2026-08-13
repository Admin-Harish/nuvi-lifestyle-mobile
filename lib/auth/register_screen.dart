/// Create an account, then verify the address.
///
/// Registration reports the same thing whether or not the address was already
/// taken, because the API does. The confirmation copy is written to be true in
/// both cases: it says a message has been sent *if the address can be used*,
/// never "welcome, your account is ready".
library;

import 'package:flutter/material.dart';

import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import 'session.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.session, super.key});

  final Session session;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();

  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final succeeded = await widget.session.register(
      email: _email.text.trim(),
      password: _password.text,
      fullName: _fullName.text.trim(),
    );
    if (!mounted) return;
    if (succeeded) {
      setState(() => _submitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final session = widget.session;

        if (_submitted) {
          return NuviPage(
            title: 'Check your inbox',
            children: [
              const NuviNotice(
                key: Key('register-sent'),
                message:
                    'If that address can be used, we have sent a verification '
                    'code to it. Enter the code to finish setting up.',
                icon: Icons.mark_email_read_outlined,
              ),
              NuviPrimaryButton(
                key: const Key('register-continue'),
                label: 'Enter my code',
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => VerifyEmailScreen(
                      session: session,
                      email: _email.text.trim(),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return NuviPage(
          title: 'Create an account',
          children: [
            if (session.error != null)
              NuviNotice(message: session.error!, icon: Icons.error_outline),
            NuviField(
              key: const Key('register-name'),
              label: 'Your name',
              controller: _fullName,
              autofillHints: const [AutofillHints.name],
            ),
            NuviField(
              key: const Key('register-email'),
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            NuviField(
              key: const Key('register-password'),
              label: 'Password',
              controller: _password,
              obscure: true,
              helper: 'At least 8 characters.',
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: NuviSpacing.sm),
            NuviPrimaryButton(
              key: const Key('register-submit'),
              label: 'Create account',
              busy: session.isBusy,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
