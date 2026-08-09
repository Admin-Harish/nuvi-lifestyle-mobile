/// Staging entrypoint.
///
///     flutter build apk -t lib/main_staging.dart \
///       --dart-define=API_BASE_URL=https://staging-api.nuvi.example
///
/// Building without `API_BASE_URL` throws at startup rather than defaulting to
/// a developer machine.
library;

import 'bootstrap.dart';
import 'config/app_environment.dart';

void main() => bootstrap(AppEnvironment.staging);
