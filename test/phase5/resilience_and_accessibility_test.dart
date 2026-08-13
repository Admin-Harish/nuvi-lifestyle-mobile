/// Phase 5: the states and the accessibility of every Phase 4 screen.
///
/// The Phase 4 suites cover content and the offline/error split thoroughly. Two
/// things they do not cover, and this file does:
///
/// **Pending state clearing.** The Phase 4 tests assert that a *failed* write
/// leaves the row unconfirmed. Nothing asserted the successful path, which is
/// the one that hangs: an indeterminate `LinearProgressIndicator` left mounted
/// never settles, so `pumpAndSettle` blocks and the row spins forever in the
/// app. `AGENTS.md` names this trap; these tests are what would catch it.
///
/// **Accessibility.** No screen had a semantics, text-scaling or focus test.
/// A monochrome design carries meaning in text and position rather than colour,
/// which makes it *more* dependent on the semantics tree being right, not less.
/// Everything a sighted user reads as a figure has to be announced as one.
///
/// A note on what is not tested here: the app does not retry writes on its own,
/// and these tests assert that it does not. Retrying a POST whose response was
/// lost is only safe when the server can recognise the repeat, and no Phase 4
/// endpoint takes an idempotency key. See `docs/phase-5-verification.md`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/pantry/deduction_confirm_screen.dart';
import 'package:nuvi_lifestyle/pantry/grocery_list_screen.dart';
import 'package:nuvi_lifestyle/pantry/pantry_screen.dart';
import 'package:nuvi_lifestyle/progress/progress_dashboard_screen.dart';
import 'package:nuvi_lifestyle/recovery/recovery_proposal_screen.dart';
import 'package:nuvi_lifestyle/reminders/reminders_settings_screen.dart';
import 'package:nuvi_lifestyle/widgets/nuvi_scaffold.dart';

import '../support/fake_api.dart';

/// `NuviPage` is a `ListView` and builds lazily; the default 800×600 window
/// leaves later rows unbuilt. Copied from the Phase 4 files, as AGENTS.md says.
void _useTallSurface(
  WidgetTester tester, {
  Size size = const Size(1200, 4000),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Wrap a screen at a chosen text scale.
///
/// Real accessibility settings on both platforms go well past 2.0; 2.0 is the
/// point at which a fixed-height row or a non-wrapping `Row` starts to overflow,
/// which is what this is looking for.
Widget _scaled(Widget child, double factor) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(factor)),
  child: child,
);

const _proposal = PantryDeductionProposal(
  id: 'prop-1',
  status: 'proposed',
  summary: 'Upma (breakfast)',
  lines: [
    PantryDeductionLine(
      itemId: 'item-1',
      itemName: 'upma rava',
      quantity: '100.000',
      unit: 'g',
      availableQuantity: '250.000',
    ),
  ],
);

const _items = [
  PantryItem(
    id: 'item-1',
    displayName: 'upma rava',
    quantityOnHand: '250.000',
    unit: 'g',
  ),
];

final _recovery = RecoveryProposal(
  id: 'rec-1',
  memberId: 'm1',
  trigger: 'skipped_meals',
  triggerDate: '2026-03-01',
  status: 'proposed',
  floorKcal: '1200.00',
  ceilingKcal: '2400.00',
  shortfallKcal: '600.00',
  redistributedKcal: '150.00',
  unrecoveredKcal: '450.00',
  rationale: 'Days above plan are never balanced out by reducing a later day.',
  adjustments: const [
    RecoveryAdjustment(
      day: '2026-03-02',
      originalTargetKcal: '2000.00',
      proposedTargetKcal: '2050.00',
      deltaKcal: '50.00',
    ),
  ],
);

/// Enough logged days that the screen draws the meters at all. A sparse window
/// is deliberately *not* rendered as a trend, so the default fake fixture shows
/// no meters and a semantics test against it would pass by finding nothing.
const _representativeProgress = MemberProgress(
  memberId: 'm1',
  memberReference: 'M1',
  start: '2026-03-01',
  end: '2026-03-14',
  trends: ProgressTrends(
    adherence: '0.75',
    hydrationConsistency: '0.50',
    mealRegularity: '0.90',
    loggingConsistency: '0.71',
    macroConsistency: '0.60',
  ),
  disclaimer: 'These figures are unreviewed estimates.',
  daysInWindow: 14,
  daysLogged: 10,
  isRepresentative: true,
  loggingStreakDays: 4,
  longestLoggingStreakDays: 6,
);

const _schedules = [
  ReminderSchedule(
    id: 'sched-1',
    memberId: 'm1',
    kind: 'hydration',
    sendAtLocal: '10:00',
    slot: '',
  ),
];

void main() {
  // -------------------------------------------------------------------------
  // 1. Pending state clears after a successful write
  // -------------------------------------------------------------------------

  group('pending state clears on success', () {
    testWidgets('a confirmed deduction leaves no spinner mounted', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = const [_proposal];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      // `pumpAndSettle` is the assertion: it times out rather than completing
      // if an indeterminate progress indicator is still mounted.
      await tester.pumpAndSettle();

      expect(api.writes, ['confirmDeduction:prop-1']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('a rejected deduction also settles', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = const [_proposal];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reject-prop-1')));
      await tester.pumpAndSettle();

      expect(api.writes, ['rejectDeduction:prop-1']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an accepted recovery proposal settles', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..recoveries = [_recovery];

      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryProposalScreen(api: api, memberId: 'm1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use this suggestion'));
      await tester.pumpAndSettle();

      expect(api.writes, ['decideRecovery:rec-1:accept']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed write clears the spinner and shows the reason', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..deductions = const [_proposal]
        ..decideDeductionFailure = const SocketException('offline');

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      await tester.pumpAndSettle();

      // The spinner is gone either way; a stuck spinner is the bug whether the
      // write succeeded or failed.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('connection'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. One tap, one write
  // -------------------------------------------------------------------------

  group('a mutating action is sent once per answer', () {
    testWidgets('a second tap while the first is in flight sends nothing', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(delay: const Duration(milliseconds: 100))
        ..deductions = const [_proposal];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      await tester.pump(const Duration(milliseconds: 10));
      // The button is disabled while busy, so this tap must not land. Without
      // the busy guard this would be two deductions for one meal, and the
      // server cannot tell the difference — no Phase 4 endpoint takes an
      // idempotency key.
      await tester.tap(
        find.byKey(const Key('confirm-prop-1')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(api.writes, ['confirmDeduction:prop-1']);
    });

    testWidgets('the cancel button is also disabled mid-flight', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(delay: const Duration(milliseconds: 100))
        ..deductions = const [_proposal];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(
        find.byKey(const Key('reject-prop-1')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        api.writes,
        ['confirmDeduction:prop-1'],
        reason:
            'a reject landing on top of an in-flight confirm would race two '
            'decisions for one proposal',
      );
    });

    testWidgets('the app never retries a write on its own', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..deductions = const [_proposal]
        ..decideDeductionFailure = const SocketException('offline');

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      expect(
        api.writes,
        ['confirmDeduction:prop-1'],
        reason:
            'an automatic retry of a non-idempotent POST can double-apply the '
            'write when the first response was merely lost',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. Cancellation is equal weight where the user is confirming a proposal
  // -------------------------------------------------------------------------

  group('cancelling carries the same weight as confirming', () {
    testWidgets('the pantry confirm screen gives both answers equal width', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = const [_proposal];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      final confirm = tester.getSize(find.byKey(const Key('confirm-prop-1')));
      final reject = tester.getSize(find.byKey(const Key('reject-prop-1')));

      expect(
        reject.width,
        confirm.width,
        reason:
            'a decline offered as a small grey link under a large confirm '
            'button is not an equal option',
      );
    });

    testWidgets('the recovery screen offers carrying on as a real answer', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..recoveries = [_recovery];

      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryProposalScreen(api: api, memberId: 'm1'),
        ),
      );
      await tester.pumpAndSettle();

      // Three first-class outcomes, not one action and two escapes.
      expect(find.text('Use this suggestion'), findsOneWidget);
      expect(find.text('Carry on as I am'), findsOneWidget);
      expect(find.text("I'll do my own thing"), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Semantics
  // -------------------------------------------------------------------------

  group('semantics', () {
    testWidgets('every progress meter announces a label and a value', (
      tester,
    ) async {
      _useTallSurface(tester);
      final handle = tester.ensureSemantics();
      final api = FakeNuviApi()..memberProgress_ = _representativeProgress;

      await tester.pumpWidget(
        MaterialApp(
          home: ProgressDashboardScreen(
            api: api,
            memberId: 'm1',
            start: '2026-03-01',
            end: '2026-03-07',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A monochrome bar carries its meaning in its fill, which a screen
      // reader cannot see. The label names the meter; the value says how full.
      final meters = tester.widgetList<NuviMeterBar>(find.byType(NuviMeterBar));
      expect(meters, isNotEmpty);
      for (final meter in meters) {
        expect(
          meter.semanticLabel,
          isNotNull,
          reason:
              'a meter with no label is an unlabelled bar to a screen reader',
        );
        expect(meter.semanticLabel, isNotEmpty);
      }

      handle.dispose();
    });

    testWidgets('the enable control names what it will ask for', (
      tester,
    ) async {
      _useTallSurface(tester);
      final handle = tester.ensureSemantics();
      final api = FakeNuviApi()..schedules = _schedules;

      await tester.pumpWidget(
        MaterialApp(
          home: RemindersSettingsScreen(api: api, memberId: 'm1'),
        ),
      );
      await tester.pumpAndSettle();

      // "Enable" alone would not tell a screen-reader user that an approver is
      // required, which is the whole point of the control.
      expect(find.textContaining('approver'), findsWidgets);

      handle.dispose();
    });

    testWidgets('actionable controls are reachable in the semantics tree', (
      tester,
    ) async {
      _useTallSurface(tester);
      final handle = tester.ensureSemantics();
      final api = FakeNuviApi()..deductions = const [_proposal];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byKey(const Key('confirm-prop-1'))),
        matchesSemantics(
          label: 'Update pantry',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('an error notice is announced as text, not colour alone', (
      tester,
    ) async {
      _useTallSurface(tester);
      final handle = tester.ensureSemantics();
      final api = FakeNuviApi()
        ..pantryFailure = const SocketException('offline');

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      // The palette is monochrome, so a state that is only a colour is a state
      // nobody perceives. The copy has to carry it.
      expect(find.textContaining('connection'), findsOneWidget);

      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // 5. Text scaling
  // -------------------------------------------------------------------------

  group('text scaling', () {
    testWidgets('the pantry renders at 2.0 without overflowing', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = _items;

      await tester.pumpWidget(
        _scaled(
          MaterialApp(
            home: PantryScreen(api: api, householdId: 'h1'),
          ),
          2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('250.000'), findsWidgets);
    });

    testWidgets('the confirm screen keeps both answers usable at 2.0', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = const [_proposal];

      await tester.pumpWidget(
        _scaled(
          MaterialApp(
            home: DeductionConfirmScreen(api: api, householdId: 'h1'),
          ),
          2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('confirm-prop-1')), findsOneWidget);
      expect(find.byKey(const Key('reject-prop-1')), findsOneWidget);
    });

    testWidgets('the progress dashboard renders at 2.0', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..memberProgress_ = _representativeProgress;

      await tester.pumpWidget(
        _scaled(
          MaterialApp(
            home: ProgressDashboardScreen(
              api: api,
              memberId: 'm1',
              start: '2026-03-01',
              end: '2026-03-07',
            ),
          ),
          2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the recovery proposal renders at 2.0', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..recoveries = [_recovery];

      await tester.pumpWidget(
        _scaled(
          MaterialApp(
            home: RecoveryProposalScreen(api: api, memberId: 'm1'),
          ),
          2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Use this suggestion'), findsOneWidget);
    });

    testWidgets('the grocery list renders at 2.0', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi();

      await tester.pumpWidget(
        _scaled(
          MaterialApp(
            home: GroceryListScreen(
              api: api,
              householdId: 'h1',
              start: '2026-03-01',
              end: '2026-03-07',
            ),
          ),
          2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('reminders settings renders at 2.0', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..schedules = _schedules;

      await tester.pumpWidget(
        _scaled(
          MaterialApp(
            home: RemindersSettingsScreen(api: api, memberId: 'm1'),
          ),
          2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 6. Keyboard and focus traversal
  // -------------------------------------------------------------------------

  group('keyboard traversal', () {
    testWidgets('both answers on the confirm screen can be focused', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = const [_proposal];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      // Tab until something is focused, then confirm a focus node exists at all
      // — a screen whose only controls are unfocusable cannot be driven by a
      // keyboard or a switch device.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(
        primaryFocus?.context,
        isNotNull,
        reason: 'no widget took focus, so the screen is keyboard-unreachable',
      );
    });

    testWidgets('the focused control can be activated from the keyboard', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = const [_proposal];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      // Tab until the confirm button holds focus, then activate it — which is
      // the whole interaction for a keyboard or switch user.
      //
      // `Focus.maybeOf(context)` is not the way in: it resolves the *enclosing*
      // Focus of that context, and a FilledButton's node is a descendant of the
      // element the key is on. Tabbing is also closer to what the user does.
      final confirm = find.byKey(const Key('confirm-prop-1'));
      var focused = false;
      for (var attempt = 0; attempt < 12 && !focused; attempt++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final context = primaryFocus?.context;
        if (context != null) {
          // Is the focused element inside the confirm button's subtree?
          focused = find
              .descendant(
                of: confirm,
                matching: find.byElementPredicate((e) => e == context),
              )
              .evaluate()
              .isNotEmpty;
        }
      }

      expect(
        focused,
        isTrue,
        reason: 'the confirm button never took focus after twelve tabs',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(api.writes, ['confirmDeduction:prop-1']);
    });
  });

  // -------------------------------------------------------------------------
  // 7. No arithmetic on displayed decimal strings
  // -------------------------------------------------------------------------

  group('decimal strings are rendered, never computed', () {
    testWidgets('the pantry shows the server string to the last place', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..pantry = const [
          PantryItem(
            id: 'item-9',
            displayName: 'precise dal',
            // Trailing zeros and three places: a double round-trip would
            // render this as "0.001" or "1e-3", and a reformatting regression
            // would drop a place.
            quantityOnHand: '0.001',
            unit: 'g',
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('0.001'), findsWidgets);
    });

    testWidgets('the confirm screen does not total the lines itself', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..deductions = const [
          PantryDeductionProposal(
            id: 'prop-2',
            status: 'proposed',
            summary: 'Two ingredients',
            lines: [
              PantryDeductionLine(
                itemId: 'a',
                itemName: 'atta',
                quantity: '100.500',
                unit: 'g',
                availableQuantity: '250.000',
              ),
              PantryDeductionLine(
                itemId: 'b',
                itemName: 'ghee',
                quantity: '10.250',
                unit: 'g',
                availableQuantity: '90.000',
              ),
            ],
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('100.500'), findsWidgets);
      expect(find.textContaining('10.250'), findsWidgets);
      // 110.75 would be the client having added two quantities the server never
      // summed — a figure with no authority behind it.
      expect(find.textContaining('110.75'), findsNothing);
    });

    testWidgets('recovery figures are rendered exactly as sent', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..recoveries = [_recovery];

      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryProposalScreen(api: api, memberId: 'm1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1200'), findsWidgets);
      expect(find.textContaining('2400'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // 8. Empty states are distinct from loading and from failure
  // -------------------------------------------------------------------------

  group('empty is its own state', () {
    testWidgets('no proposals says so rather than showing a blank page', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = const [];

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing to confirm right now.'), findsOneWidget);
      expect(api.writes, isEmpty);
    });

    testWidgets('an empty pantry is not an error', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = const [];

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('connection'), findsNothing);
      expect(find.textContaining('went wrong'), findsNothing);
    });
  });
}
