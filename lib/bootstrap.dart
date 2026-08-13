/// Wiring shared by every entrypoint.
///
/// Each flavor's `main` resolves its [AppConfig] — which is where a staging or
/// production build without `API_BASE_URL` throws — and then hands it here.
/// Keeping the wiring in one place means the three entrypoints differ only in
/// the flavor they pass, which is the only thing that should differ.
library;

import 'package:flutter/widgets.dart';

import 'api/nuvi_api.dart';
import 'app.dart';
import 'auth/session.dart';
import 'config/app_config.dart';
import 'config/app_environment.dart';

void bootstrap(AppEnvironment environment) {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.resolve(environment);
  final api = HttpNuviApi(config: config);
  runApp(
    NuviLifestyleApp(
      config: config,
      api: api,
      session: Session(api: api),
    ),
  );
}
