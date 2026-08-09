import 'package:flutter/foundation.dart';

import 'app_environment.dart';

/// Runtime configuration, resolved once at startup.
///
/// The API base URL comes from the `API_BASE_URL` compile-time define:
///
/// ```
/// flutter build apk --dart-define=API_BASE_URL=https://api.nuvi.example
/// ```
///
/// Shipping flavors have **no default**. If a staging or production build is
/// made without `API_BASE_URL`, [AppConfig.resolve] throws at startup rather
/// than silently falling back to a developer machine — a release pointed at
/// `localhost` is worse than a build that refuses to start.
///
/// Development defaults to the local API so a new contributor can run the app
/// immediately, and can still override it for a device on the same network.
@immutable
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.apiTimeout,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final Duration apiTimeout;

  /// The local API when running in an Android emulator is reachable on
  /// 10.0.2.2; on iOS simulators and desktop it is plain localhost.
  static const String _developmentFallbackUrl = 'http://localhost:8000';

  static const String _apiBaseUrlFromEnvironment = String.fromEnvironment(
    'API_BASE_URL',
  );

  static const int _apiTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 30,
  );

  static AppConfig resolve(AppEnvironment environment) {
    final defined = _apiBaseUrlFromEnvironment.trim();

    if (defined.isEmpty && environment != AppEnvironment.development) {
      throw StateError(
        'API_BASE_URL was not provided for the ${environment.label} build. '
        'Pass it at build time, e.g. '
        '--dart-define=API_BASE_URL=https://api.nuvi.example. '
        'Shipping builds have no default on purpose.',
      );
    }

    final baseUrl = defined.isEmpty ? _developmentFallbackUrl : defined;
    final normalised = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (environment.isProduction && !normalised.startsWith('https://')) {
      throw StateError(
        'A production build must use an https:// API base URL; got "$normalised".',
      );
    }

    return AppConfig(
      environment: environment,
      apiBaseUrl: normalised,
      apiTimeout: const Duration(seconds: _apiTimeoutSeconds),
    );
  }

  /// Full URL for a versioned API path, e.g. `ops/health/`.
  Uri apiUri(String path) {
    final trimmed = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$apiBaseUrl/api/v1/$trimmed');
  }

  @override
  String toString() =>
      'AppConfig(environment: ${environment.label}, apiBaseUrl: $apiBaseUrl)';
}
