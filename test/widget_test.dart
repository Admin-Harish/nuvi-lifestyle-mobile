import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/app.dart';
import 'package:nuvi_lifestyle/config/app_config.dart';
import 'package:nuvi_lifestyle/config/app_environment.dart';
import 'package:nuvi_lifestyle/theme/nuvi_tokens.dart';

void main() {
  const devConfig = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: 'http://localhost:8000',
    apiTimeout: Duration(seconds: 30),
  );

  group('app shell', () {
    testWidgets('boots and shows the build it is pointed at', (tester) async {
      await tester.pumpWidget(const NuviLifestyleApp(config: devConfig));

      expect(find.text('Nuvi Lifestyle'), findsOneWidget);
      expect(find.text('Phase 0'), findsOneWidget);
      expect(find.text('dev'), findsOneWidget);
      expect(find.text('http://localhost:8000'), findsOneWidget);
    });

    testWidgets('production builds hide the debug banner', (tester) async {
      const prodConfig = AppConfig(
        environment: AppEnvironment.production,
        apiBaseUrl: 'https://api.nuvi.example',
        apiTimeout: Duration(seconds: 30),
      );

      await tester.pumpWidget(const NuviLifestyleApp(config: prodConfig));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, isFalse);
    });
  });

  group('AppConfig', () {
    test('builds versioned API URLs', () {
      expect(
        devConfig.apiUri('ops/health/').toString(),
        'http://localhost:8000/api/v1/ops/health/',
      );
      // A leading slash on the path must not produce a double slash.
      expect(
        devConfig.apiUri('/ops/readiness/').toString(),
        'http://localhost:8000/api/v1/ops/readiness/',
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
