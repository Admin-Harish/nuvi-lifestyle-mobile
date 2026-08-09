/// Development entrypoint.
///
///     flutter run -t lib/main_dev.dart
///     flutter run -t lib/main_dev.dart --dart-define=API_BASE_URL=http://192.168.1.10:8000
library;

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/app_environment.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.resolve(AppEnvironment.development);
  runApp(NuviLifestyleApp(config: config));
}
