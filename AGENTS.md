# nuvi-lifestyle-mobile

Flutter client for Nuvi Lifestyle. Flutter 3.44.7 stable, Dart 3.12+.
Backend: [nuvi-lifestyle-api](https://github.com/Admin-Harish/nuvi-lifestyle-api).

Small tree — read `lib/` directly rather than trusting the README's layout
section, which is stale.

## Where to look

| You are changing | Go to |
| --- | --- |
| A network call or wire model | `lib/api/nuvi_api.dart`, `lib/api/models.dart` |
| Sign-in, registration, session state | `lib/auth/` — `session.dart` first |
| A screen | `lib/<domain>/*_screen.dart` (`auth`, `goals`, `consent`, `menus`, `plans`) |
| Base URL, flavors, startup guards | `lib/config/app_config.dart`, `app_environment.dart` |
| Colour, spacing, type | `lib/theme/nuvi_tokens.dart` |
| Shared page/notice/field/button | `lib/widgets/nuvi_scaffold.dart` |

## Commands

```bash
flutter analyze     # must be clean; CI runs --fatal-infos --fatal-warnings
flutter test
./scripts/run.sh dev
```

Three flavors, three entrypoints, three application IDs, so all can be
installed side by side: `lib/main_dev.dart` / `main_staging.dart` /
`main_prod.dart`. Config is a compile-time `--dart-define`, never a runtime file.

## Invariants

- **No shipped build can point at localhost.** `AppConfig.resolve` throws at
  startup if a staging or production build has no `API_BASE_URL`, or if a
  production URL is not `https://`. Only development has a fallback, and it is
  the only permitted mention of a local address in `lib/` — CI greps for the rest.
- **Every credential failure shows one message** (`genericAuthFailure`),
  whatever the server said. Per-field sign-in errors would reintroduce, in the
  UI, the account enumeration the API avoids.
- **The client renders server decisions; it never makes them.** Gated goals are
  displayed inert because the server gated them. There is no call that carries
  a role or capability claim — do not add one.
- **Screens read semantic theme tokens** (`NuviColors.onSurface`), never the
  ramp and never a literal colour. The palette is monochrome and a test fails
  the build on a stray hue.
- **`.env.example` contains variable names only.** CI fails on any value.

## Traps

- `lib/theme/nuvi_tokens.dart` holds deliberate Phase 0 stubs; exact values,
  elevation, motion and dark mode belong to Phase 7B. `NuviTheme.dark` returns
  the light theme on purpose — do not invent a dark palette.
- Release builds are currently signed with the debug key so `flutter run
  --release` works locally. A real upload key is an Infrastructure task before
  any store submission.
- `main` here **is** branch-protected and requires both CI checks.
