/// Phase 6 (mobile) — the client half of the idempotency and replay contract.
///
/// The server (nuvi-lifestyle-api PR #8) makes pantry create/adjust idempotent
/// on a client-supplied key and makes a repeated decision return the current
/// state instead of a 400. This file proves the client holds up its end:
///
/// * a retried adjustment carries the **same** key, so the server absorbs it as
///   one write;
/// * a genuinely new adjustment carries a **fresh** key, so it is not mistaken
///   for a replay — and cannot be rejected as a payload conflict;
/// * a decision that succeeds (which, server-side, may be a replay) clears its
///   pending state and shows no error;
/// * a 409 conflict reloads to the current state rather than showing a false
///   "please try again" for a request whose answer has already moved on.
///
/// The create path has no screen yet, so the mobile key contract for it is the
/// `required String idempotencyKey` parameter (a compile-time guarantee) plus
/// the API-side tests. This file covers the paths a user can actually reach.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/api/nuvi_api.dart';
import 'package:nuvi_lifestyle/pantry/deduction_confirm_screen.dart';
import 'package:nuvi_lifestyle/pantry/pantry_screen.dart';
import 'package:nuvi_lifestyle/recovery/recovery_proposal_screen.dart';

import '../support/fake_api.dart';

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _items = [
  PantryItem(
    id: 'item-1',
    displayName: 'upma rava',
    quantityOnHand: '250.000',
    unit: 'g',
  ),
];

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

Future<void> _pumpPantry(WidgetTester tester, FakeNuviApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PantryScreen(api: api, householdId: 'h1'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  // 1. One key per logical action, stable across a retry
  // -------------------------------------------------------------------------

  group('pantry adjust idempotency keys', () {
    testWidgets('a retried adjustment reuses the same key', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..pantry = _items
        ..adjustFailure = const SocketException('no route');

      await _pumpPantry(tester, api);

      // First attempt fails (offline). The key is recorded, and kept.
      await tester.tap(find.byKey(const Key('pantry-bought-item-1')).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);

      // The user retries the same adjustment; this time it lands.
      api.adjustFailure = null;
      await tester.tap(find.byKey(const Key('pantry-bought-item-1')).first);
      await tester.pumpAndSettle();

      expect(api.pantryWriteKeys.length, 2);
      expect(
        api.pantryWriteKeys[0],
        api.pantryWriteKeys[1],
        reason:
            'a retry of the same adjustment must carry the same key so the '
            'server recognises it as one write, not two',
      );
    });

    testWidgets('a genuinely new adjustment gets a fresh key', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = _items;

      await _pumpPantry(tester, api);

      // Two separate purchases of the same item — two real events.
      await tester.tap(find.byKey(const Key('pantry-bought-item-1')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pantry-bought-item-1')).first);
      await tester.pumpAndSettle();

      expect(api.pantryWriteKeys.length, 2);
      expect(
        api.pantryWriteKeys[0],
        isNot(api.pantryWriteKeys[1]),
        reason:
            'a new action after a successful one must not reuse the old key, '
            'or the server would absorb a real second purchase as a duplicate',
      );
    });

    testWidgets('different adjustments carry different keys', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = _items;

      await _pumpPantry(tester, api);

      await tester.tap(find.byKey(const Key('pantry-bought-item-1')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pantry-used-item-1')).first);
      await tester.pumpAndSettle();

      expect(api.writes, [
        'adjust:item-1:100:purchase',
        'adjust:item-1:-100:other',
      ]);
      expect(
        api.pantryWriteKeys[0],
        isNot(api.pantryWriteKeys[1]),
        reason:
            'a buy and a use are different payloads and need different keys',
      );
    });

    testWidgets('every adjustment carries a non-empty key', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = _items;

      await _pumpPantry(tester, api);
      await tester.tap(find.byKey(const Key('pantry-bought-item-1')).first);
      await tester.pumpAndSettle();

      expect(api.pantryWriteKeys.single, isNotEmpty);
    });

    testWidgets('an offline adjustment says offline, not conflict', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..pantry = _items
        ..adjustFailure = const SocketException('no route');

      await _pumpPantry(tester, api);
      await tester.tap(find.byKey(const Key('pantry-bought-item-1')).first);
      await tester.pumpAndSettle();

      // Offline and conflict are different states with different copy.
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.textContaining('already updated'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Decisions: a successful (possibly replayed) decision, and a conflict
  // -------------------------------------------------------------------------

  group('deduction decision replay and conflict', () {
    testWidgets('a successful confirm clears pending and shows no error', (
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
      await tester.pumpAndSettle();

      // A repeat of this confirm is a 200 server-side; to the client a decision
      // that does not throw is a success. No error, no stuck spinner.
      expect(api.writes, ['confirmDeduction:prop-1']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('went wrong'), findsNothing);
      expect(find.textContaining('offline'), findsNothing);
    });

    testWidgets('a 409 conflict reloads to current state, not a false error', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..deductions = const [_proposal]
        ..decideDeductionFailure = ApiException(409, 'already decided');

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      await tester.pumpAndSettle();

      // The conflicting decision must not surface a "please try again" banner;
      // it reloads the list to show the current, already-settled state.
      expect(find.textContaining('went wrong'), findsNothing);
      expect(
        api.calls.where((c) => c == 'pantryDeductions').length,
        greaterThanOrEqualTo(2),
        reason: 'a conflict reloads the proposals to show current state',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('offline on a confirm still says offline, not conflict', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..deductions = const [_proposal]
        ..decideDeductionFailure = const SocketException('no route');

      await tester.pumpWidget(
        MaterialApp(
          home: DeductionConfirmScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsOneWidget);
    });
  });

  group('recovery decision replay and conflict', () {
    testWidgets('a successful decision clears pending and shows no error', (
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

      await tester.tap(find.text('Use this suggestion'));
      await tester.pumpAndSettle();

      expect(api.writes, ['decideRecovery:rec-1:accept']);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('went wrong'), findsNothing);
    });

    testWidgets('a 409 conflict reloads to current state', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..recoveries = [_recovery]
        ..decideRecoveryFailure = ApiException(409, 'already decided');

      await tester.pumpWidget(
        MaterialApp(
          home: RecoveryProposalScreen(api: api, memberId: 'm1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use this suggestion'));
      await tester.pumpAndSettle();

      expect(find.textContaining('went wrong'), findsNothing);
      expect(
        api.calls.where((c) => c == 'recoveryProposals').length,
        greaterThanOrEqualTo(2),
        reason: 'a conflicting decision reloads to show the settled state',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. The conflict classifier
  // -------------------------------------------------------------------------

  group('conflict is its own failure state', () {
    test('a 409 classifies as conflict, distinct from refused and other', () {
      // Imported transitively via the screens above; assert the mapping here so
      // a regression in the classifier fails loudly rather than as odd copy.
      expect(ApiException(409, 'x').isConflict, isTrue);
      expect(ApiException(403, 'x').isConflict, isFalse);
      expect(ApiException(500, 'x').isConflict, isFalse);
    });
  });
}
