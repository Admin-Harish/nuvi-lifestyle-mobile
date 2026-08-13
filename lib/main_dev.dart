/// Development entrypoint.
///
///     flutter run -t lib/main_dev.dart
///     flutter run -t lib/main_dev.dart --dart-define=API_BASE_URL=http://192.168.1.10:8000
library;

import 'bootstrap.dart';
import 'config/app_environment.dart';

void main() => bootstrap(AppEnvironment.development);
