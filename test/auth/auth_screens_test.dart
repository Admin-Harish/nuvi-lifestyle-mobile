/// The auth screens, and the one property that matters most about them:
/// they say the same thing for every credential failure.
///
/// The API is careful not to reveal whether an address exists. That protection
/// is only worth anything if the UI is equally careful, so these tests assert
/// on the exact rendered string rather than on "an error appeared".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/nuvi_api.dart';
import 'package:nuvi_lifestyle/auth/login_screen.dart';
import 'package:nuvi_lifestyle/auth/register_screen.dart';
import 'package:nuvi_lifestyle/auth/session.dart';
import 'package:nuvi_lifestyle/auth/verify_email_screen.dart';

import '../support/fake_api.dart';

Widget _host(Widget child) => MaterialApp(home: child);

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('login-email')), 'a@example.com');
  await tester.enterText(find.byKey(const Key('login-password')), 'secret-123');
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

void main() {
  group('login', () {
    testWidgets('signs in and reports no error', (tester) async {
      final api = FakeNuviApi();
      final session = Session(api: api);
      await tester.pumpWidget(_host(LoginScreen(session: session)));

      await _signIn(tester);

      expect(session.isSignedIn, isTrue);
      expect(session.error, isNull);
      expect(api.calls, contains('login:a@example.com'));
    });

    testWidgets('an unknown address and a wrong password read identically', (
      tester,
    ) async {
      // The server answers 401 with the same body for both. The UI must not
      // reintroduce the distinction it was careful to remove.
      final messages = <String>[];

      for (final failure in [
        ApiException(401, 'Invalid credentials.'),
        ApiException(401, 'Invalid credentials.'),
      ]) {
        final session = Session(api: FakeNuviApi(loginFailure: failure));
        await tester.pumpWidget(_host(LoginScreen(session: session)));
        await _signIn(tester);
        messages.add(session.error!);
      }

      expect(messages.first, messages.last);
      expect(messages.first, genericAuthFailure);
    });

    testWidgets('the server detail is never rendered verbatim', (tester) async {
      // A future server change that leaked "no such user" in `detail` must not
      // reach the screen.
      final session = Session(
        api: FakeNuviApi(
          loginFailure: ApiException(401, 'No account exists for that email.'),
        ),
      );
      await tester.pumpWidget(_host(LoginScreen(session: session)));

      await _signIn(tester);

      expect(find.textContaining('No account exists'), findsNothing);
      expect(find.text(genericAuthFailure), findsOneWidget);
    });

    testWidgets('a network failure is not reported as a bad password', (
      tester,
    ) async {
      final session = Session(
        api: FakeNuviApi(loginFailure: const SocketExceptionStub()),
      );
      await tester.pumpWidget(_host(LoginScreen(session: session)));

      await _signIn(tester);

      expect(find.text(networkFailure), findsOneWidget);
      expect(find.text(genericAuthFailure), findsNothing);
    });

    testWidgets('being rate-limited says so, without naming the account', (
      tester,
    ) async {
      final session = Session(
        api: FakeNuviApi(loginFailure: ApiException(429, 'Throttled.')),
      );
      await tester.pumpWidget(_host(LoginScreen(session: session)));

      await _signIn(tester);

      expect(find.text(throttledFailure), findsOneWidget);
    });

    testWidgets('the submit button is disabled while a sign-in is in flight', (
      tester,
    ) async {
      final session = Session(
        api: FakeNuviApi(delay: const Duration(milliseconds: 50)),
      );
      await tester.pumpWidget(_host(LoginScreen(session: session)));

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'a@example.com',
      );
      await tester.enterText(find.byKey(const Key('login-password')), 'pw');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump(); // one frame: the call is still in flight

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('login-submit')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);

      await tester.pumpAndSettle();
    });

    testWidgets('a password reset is acknowledged whatever the address', (
      tester,
    ) async {
      final api = FakeNuviApi();
      final session = Session(api: api);
      await tester.pumpWidget(_host(LoginScreen(session: session)));

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'ghost@example.com',
      );
      await tester.tap(find.byKey(const Key('login-forgot')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('If that address can be used'),
        findsOneWidget,
      );
    });
  });

  group('register', () {
    testWidgets('confirmation never claims the account was created', (
      tester,
    ) async {
      final session = Session(api: FakeNuviApi());
      await tester.pumpWidget(_host(RegisterScreen(session: session)));

      await tester.enterText(
        find.byKey(const Key('register-email')),
        'new@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register-password')),
        'a-strong-passphrase',
      );
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();

      // "If that address can be used" — true whether it was new or taken.
      expect(find.byKey(const Key('register-sent')), findsOneWidget);
      expect(
        find.textContaining('If that address can be used'),
        findsOneWidget,
      );
      expect(find.textContaining('Welcome'), findsNothing);
    });

    testWidgets('a duplicate address produces the same screen', (tester) async {
      // The fake succeeds for both, because the server does.
      final api = FakeNuviApi();
      final session = Session(api: api);
      await tester.pumpWidget(_host(RegisterScreen(session: session)));

      await tester.enterText(
        find.byKey(const Key('register-email')),
        'taken@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register-password')),
        'a-strong-passphrase',
      );
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register-sent')), findsOneWidget);
      expect(find.textContaining('already'), findsNothing);
    });
  });

  group('verify email', () {
    testWidgets('a valid code confirms the address', (tester) async {
      final api = FakeNuviApi();
      final session = Session(api: api);
      await tester.pumpWidget(
        _host(VerifyEmailScreen(session: session, email: 'a@example.com')),
      );

      await tester.enterText(find.byKey(const Key('verify-code')), '123456');
      await tester.tap(find.byKey(const Key('verify-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('verify-done')), findsOneWidget);
      expect(api.calls, contains('verify:a@example.com:123456'));
    });

    testWidgets('a bad code does not say why it was bad', (tester) async {
      final session = Session(
        api: FakeNuviApi(
          verifyFailure: ApiException(400, 'That code is not valid.'),
        ),
      );
      await tester.pumpWidget(
        _host(VerifyEmailScreen(session: session, email: 'a@example.com')),
      );

      await tester.enterText(find.byKey(const Key('verify-code')), '000000');
      await tester.tap(find.byKey(const Key('verify-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('verify-done')), findsNothing);
      for (final leak in ['expired', 'already used', 'no such']) {
        expect(find.textContaining(leak), findsNothing);
      }
    });
  });
}

/// Stands in for a transport failure without importing `dart:io` into a test
/// that has no other reason to.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
