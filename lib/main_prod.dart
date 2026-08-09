/// Production entrypoint.
///
///     flutter build appbundle -t lib/main_prod.dart \
///       --dart-define=API_BASE_URL=https://api.nuvi.example
///
/// A production build refuses to start without `API_BASE_URL`, and refuses a
/// non-https URL.
library;

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/app_environment.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.resolve(AppEnvironment.production);
  runApp(NuviLifestyleApp(config: config));
}
