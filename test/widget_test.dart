/// The app shell, the build configuration and the theme tokens.
///
/// The configuration tests are the important ones and are unchanged from
/// Phase 0: a staging or production build with no `API_BASE_URL` must refuse
/// to start rather than quietly pointing at a developer machine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/app.dart';
import 'package:nuvi_lifestyle/auth/session.dart';
import 'package:nuvi_lifestyle/config/app_config.dart';
import 'package:nuvi_lifestyle/config/app_environment.dart';
import 'package:nuvi_lifestyle/theme/nuvi_tokens.dart';

import 'support/fake_api.dart';

void main() {
  const devConfig = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: 'http://127.0.0.1:8000',
    apiTimeout: Duration(seconds: 30),
  );

  group('app shell', () {
    testWidgets('a signed-out app opens on sign in', (tester) async {
      final api = FakeNuviApi();
      await tester.pumpWidget(
        NuviLifestyleApp(
          config: devConfig,
          api: api,
          session: Session(api: api),
        ),
      );

      // 'Sign in' is both the app-bar title and the button label.
      expect(find.text('Sign in'), findsWidgets);
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
    });

    testWidgets('signing in reveals the goals and consent tabs', (
      tester,
    ) async {
      final api = FakeNuviApi(
        goals: sampleGoals(),
        consents: sampleDraftConsents(),
      );
      final session = Session(api: api);
      await tester.pumpWidget(
        NuviLifestyleApp(config: devConfig, api: api, session: session),
      );

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'meera.nair@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'a-passphrase',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Meera Nair'), findsOneWidget);
      expect(find.text('Goals'), findsWidgets);
      expect(find.text('Consent'), findsWidgets);
    });

    testWidgets('roles are displayed but carry no authority', (tester) async {
      // Shown for transparency. The server authorises every action regardless
      // of what this row says, which is why the app can display it safely.
      final api = FakeNuviApi();
      final session = Session(api: api);
      await tester.pumpWidget(
        NuviLifestyleApp(config: devConfig, api: api, session: session),
      );

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'meera.nair@example.com',
      );
      await tester.enterText(find.byKey(const Key('login-password')), 'pw');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-roles')), findsOneWidget);
      expect(find.text('member, household_caregiver'), findsOneWidget);
    });

    testWidgets('signing out returns to sign in', (tester) async {
      final api = FakeNuviApi();
      final session = Session(api: api);
      await tester.pumpWidget(
        NuviLifestyleApp(config: devConfig, api: api, session: session),
      );

      await tester.enterText(
        find.byKey(const Key('login-email')),
        'a@example.com',
      );
      await tester.enterText(find.byKey(const Key('login-password')), 'pw');
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign-out')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-submit')), findsOneWidget);
      expect(session.user, isNull);
    });

    testWidgets('production builds hide the debug banner', (tester) async {
      const prodConfig = AppConfig(
        environment: AppEnvironment.production,
        apiBaseUrl: 'https://api.nuvi.example',
        apiTimeout: Duration(seconds: 30),
      );
      final api = FakeNuviApi();

      await tester.pumpWidget(
        NuviLifestyleApp(
          config: prodConfig,
          api: api,
          session: Session(api: api),
        ),
      );

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, isFalse);
    });
  });

  group('AppConfig', () {
    test('builds versioned API URLs', () {
      expect(
        devConfig.apiUri('ops/health/').toString(),
        'http://127.0.0.1:8000/api/v1/ops/health/',
      );
      // A leading slash on the path must not produce a double slash.
      expect(
        devConfig.apiUri('/ops/readiness/').toString(),
        'http://127.0.0.1:8000/api/v1/ops/readiness/',
      );
    });

    test('development resolves without a compile-time API_BASE_URL', () {
      // No --dart-define in `flutter test`, so this exercises the dev fallback.
      final config = AppConfig.resolve(AppEnvironment.development);

      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUrl, isNotEmpty);
    });

    test('staging refuses to build without an explicit API_BASE_URL', () {
      // The guarantee that matters: a shipped build can never silently point
      // at a developer machine.
      expect(
        () => AppConfig.resolve(AppEnvironment.staging),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('API_BASE_URL was not provided'),
          ),
        ),
      );
    });

    test('production refuses to build without an explicit API_BASE_URL', () {
      expect(
        () => AppConfig.resolve(AppEnvironment.production),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('theme tokens', () {
    test('the palette is monochrome', () {
      const palette = <Color>[
        NuviColors.black,
        NuviColors.ink900,
        NuviColors.ink700,
        NuviColors.ink500,
        NuviColors.ink300,
        NuviColors.ink200,
        NuviColors.ink100,
        NuviColors.ink50,
        NuviColors.white,
        NuviColors.primary,
        NuviColors.onPrimary,
        NuviColors.surface,
        NuviColors.onSurface,
        NuviColors.border,
        NuviColors.danger,
        NuviColors.success,
      ];

      for (final color in palette) {
        expect(
          color.r == color.g && color.g == color.b,
          isTrue,
          reason:
              'Nuvi is black and white: every token must have equal RGB '
              'channels, but $color does not.',
        );
      }
    });

    test('spacing follows a 4pt scale', () {
      const scale = <double>[
        NuviSpacing.xs,
        NuviSpacing.sm,
        NuviSpacing.md,
        NuviSpacing.lg,
        NuviSpacing.xl,
        NuviSpacing.xxl,
        NuviSpacing.xxxl,
      ];

      for (final step in scale) {
        expect(step % 4, 0, reason: '$step is not on the 4pt scale');
      }
    });
  });
}
