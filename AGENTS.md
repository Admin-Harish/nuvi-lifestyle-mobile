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
| A screen | `lib/<domain>/*_screen.dart` (`auth`, `goals`, `consent`, `menus`, `plans`, `tracking`, `pantry`, `reminders`, `progress`, `recovery`) |
| Loading / error / offline states | `lib/widgets/request_state.dart` — `NuviAsync` and `classifyFailure` |
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
- **Offline is a distinct state from error.** `classifyFailure` in
  `lib/widgets/request_state.dart` is the one place that decides, and
  `RequestFailure.refused` gets no retry button — hammering an endpoint that
  will never say yes is not a recovery path. Every screen's tests assert the
  offline and error copy separately, because a test for "some notice appeared"
  passes with the message that tells somebody on full signal to check their
  connection.
- **Confirm gates are real screens, not dialogs bolted onto a write.** A pantry
  deduction and a recovery proposal each have a screen whose job is to ask, and
  the widget tests assert that `api.writes` is empty until the user answers. The
  server refuses to act without the confirmation; the client must not pretend
  otherwise by pre-sending it.
- **Nothing in `lib/` decides what a member is allowed to do.** A reminder
  cannot be enabled without an approver because `enableReminder` requires the
  argument and the server requires the value — not because a screen checks a
  role. `requires_approval_to_enable` arrives on the wire and is rendered.
- **`.env.example` contains variable names only.** CI fails on any value.

## Traps

- Quantities and macros arrive as **decimal strings and are rendered as
  strings**. Parsing one to a double reintroduces the binary rounding the server
  avoided; the widget tests assert exact strings like `250.000 g` so a
  reformatting regression fails rather than shipping.
- A `NuviPage` is a `ListView` and builds lazily. On the default 800×600 test
  window later rows are never constructed, so a finder reports "not found" for a
  layout reason. Every Phase 4 test file sets a tall surface — copy
  `_useTallSurface`.
- After a successful write, clear the pending marker in the reload as well as in
  the failure path. An indeterminate `LinearProgressIndicator` left mounted
  never settles, so `pumpAndSettle` hangs and the row spins forever in the app.
- `lib/theme/nuvi_tokens.dart` holds deliberate Phase 0 stubs; exact values,
  elevation, motion and dark mode belong to Phase 7B. `NuviTheme.dark` returns
  the light theme on purpose — do not invent a dark palette.
- Release builds are currently signed with the debug key so `flutter run
  --release` works locally. A real upload key is an Infrastructure task before
  any store submission.
- `main` here **is** branch-protected and requires both CI checks.
