/// Production entrypoint.
///
///     flutter build appbundle -t lib/main_prod.dart \
///       --dart-define=API_BASE_URL=https://api.nuvi.example
///
/// A production build refuses to start without `API_BASE_URL`, and refuses a
/// non-https URL.
library;

import 'bootstrap.dart';
import 'config/app_environment.dart';

void main() => bootstrap(AppEnvironment.production);
