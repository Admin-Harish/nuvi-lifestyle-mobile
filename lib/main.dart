/// Default entrypoint — development.
///
/// `flutter run` with no arguments lands here. Staging and production builds
/// must use `lib/main_staging.dart` and `lib/main_prod.dart`, which cannot be
/// built without an explicit `API_BASE_URL`.
library;

import 'main_dev.dart' as dev;

void main() => dev.main();
