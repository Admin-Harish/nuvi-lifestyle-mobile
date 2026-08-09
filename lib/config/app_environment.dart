/// Build flavors.
///
/// The flavor is chosen by the entrypoint (`lib/main_dev.dart`,
/// `main_staging.dart`, `main_prod.dart`), never guessed at runtime. Each
/// entrypoint passes its flavor to [AppConfig], so a build cannot end up
/// pointing somewhere it was not built for.
enum AppEnvironment {
  development,
  staging,
  production;

  /// Short label for logs and the debug banner.
  String get label => switch (this) {
    AppEnvironment.development => 'dev',
    AppEnvironment.staging => 'staging',
    AppEnvironment.production => 'prod',
  };

  /// Only production is a shipping build. Non-production builds may show
  /// diagnostics; production never does.
  bool get isProduction => this == AppEnvironment.production;

  bool get showDebugBanner => this != AppEnvironment.production;
}
