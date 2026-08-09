/// Redeem a verification code.
///
/// The code is short-lived and attempt-capped on the server. This screen does
/// not say *why* a code failed — expired, wrong, or already used all read the
/// same, which is what the API returns and what stops the endpoint being used
/// to probe.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/nuvi_tokens.dart';
import '../widgets/nuvi_scaffold.dart';
import 'session.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    required this.session,
    required this.email,
    super.key,
  });

  final Session session;
  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _verified = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final succeeded = await widget.session.verifyEmail(
      email: widget.email,
      code: _code.text.trim(),
    );
    if (!mounted) return;
    if (succeeded) setState(() => _verified = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final session = widget.session;

        if (_verified) {
          return NuviPage(
            title: 'Verified',
            children: [
              const NuviNotice(
                key: Key('verify-done'),
                message: 'Your email address is verified. You can sign in now.',
                icon: Icons.check_circle_outline,
              ),
              NuviPrimaryButton(
                label: 'Back to sign in',
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          );
        }

        return NuviPage(
          title: 'Enter your code',
          children: [
            Text(
              'We sent a code to ${widget.email}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: NuviSpacing.lg),
            if (session.error != null)
              NuviNotice(message: session.error!, icon: Icons.error_outline),
            Padding(
              padding: const EdgeInsets.only(bottom: NuviSpacing.lg),
              child: TextField(
                key: const Key('verify-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  helperText: 'Six digits. It expires in 15 minutes.',
                ),
              ),
            ),
            NuviPrimaryButton(
              key: const Key('verify-submit'),
              label: 'Verify',
              busy: session.isBusy,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
