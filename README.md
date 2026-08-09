# Nuvi Lifestyle — mobile

Flutter client for Nuvi Lifestyle, a nutrition and meal-planning product for
India.

**This is a greenfield project.** It shares no code with the existing NUVI app.

**Phase 0 status: bootstrap only.** There are no product screens — no food
catalogue, no menus, no goals. What exists is the flavor plumbing, a
configurable API base URL, theme-token stubs, and CI. This is not production
ready and is not claimed to be.

---

## Requirements

* Flutter 3.44.7 (stable), Dart 3.12+
* Xcode for iOS, Android Studio (or a JDK 17+) for Android

## Setup

```bash
flutter pub get
flutter run -t lib/main_dev.dart
```

Development defaults to `http://localhost:8000`, so it works against a locally
running [nuvi-lifestyle-api](https://github.com/Admin-Harish/nuvi-lifestyle-api)
with no further setup.

To point a dev build at another host (a device on your network, say):

```bash
flutter run -t lib/main_dev.dart --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

---

## Flavors

Three flavors, each with its own entrypoint and its own Android application ID,
so all three can be installed side by side and a staging build can never
upgrade over production.

| Flavor | Entrypoint | Application ID | API base URL |
| --- | --- | --- | --- |
| `dev` | `lib/main_dev.dart` | `com.nuvi.lifestyle.dev` | defaults to `http://localhost:8000` |
| `staging` | `lib/main_staging.dart` | `com.nuvi.lifestyle.staging` | **required** at build time |
| `prod` | `lib/main_prod.dart` | `com.nuvi.lifestyle` | **required**, must be `https://` |

Configuration is a compile-time `--dart-define`, not a runtime file:

```bash
flutter build appbundle \
  --flavor prod \
  -t lib/main_prod.dart \
  --dart-define=API_BASE_URL=https://api.nuvi.example
```

Or use the helpers, which read `API_BASE_URL` from the environment and refuse
to build a shipping flavor without it:

```bash
./scripts/run.sh dev
API_BASE_URL=https://staging-api.nuvi.example ./scripts/build.sh staging apk
API_BASE_URL=https://api.nuvi.example         ./scripts/build.sh prod appbundle
```

### No shipped build can point at localhost

`AppConfig.resolve` throws at startup if a staging or production build was made
without `API_BASE_URL`, and throws if a production build was given a non-HTTPS
URL. Only development has a fallback. A build that refuses to start is better
than a release quietly talking to a developer's laptop — and there are tests
for both cases.

---

## Tests

```bash
flutter analyze     # must be clean
flutter test
```

The suite covers the app shell, the flavor guarantees (staging and production
refuse to resolve without an explicit base URL), URL construction, and the
theme tokens — including an assertion that every colour token is monochrome,
so a stray accent colour fails the build.

---

## Theme tokens

`lib/theme/nuvi_tokens.dart` holds **Phase 0 stubs** for the black-and-white
design system, which is fully defined in Phase 7B. They exist now so screens
built before then inherit token names instead of scattering literal colours
that later have to be hunted down.

What will not change in 7B:

* the palette is monochrome — no hue, no accent colour;
* screens read a semantic token (`NuviColors.onSurface`), never the ramp
  (`NuviColors.ink900`) and never a literal;
* spacing is a 4pt scale.

Exact values, elevation, motion and dark-mode mapping are 7B's to decide.
`NuviTheme.dark` currently returns the light theme rather than inventing a
palette 7B would have to undo.

---

## Project layout

```
lib/
  main.dart           delegates to the dev entrypoint
  main_dev.dart       main_staging.dart       main_prod.dart
  app.dart            application shell and the Phase 0 bootstrap screen
  config/
    app_environment.dart   the three flavors
    app_config.dart        API base URL resolution and its guards
  theme/
    nuvi_tokens.dart       colour, spacing, radius, type (Phase 0 stubs)
    nuvi_theme.dart        ThemeData assembled from the tokens
scripts/
  run.sh  build.sh
test/
  widget_test.dart
```

---

## Guardrails in force

Phase 0 deliberately does not include any product screen or feature domain, no
payments, AI, gated clinical content or health-platform sync. CI asserts there
is no hardcoded local address outside the development fallback, and that
`.env.example` contains names only.

Signing note: release builds are currently signed with the debug key so
`flutter run --release` works locally. A real upload key and its custody are an
Infrastructure task before any store submission.
