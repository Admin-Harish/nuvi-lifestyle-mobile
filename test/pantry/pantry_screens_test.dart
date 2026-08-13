/// The pantry, the reconciled shopping list, and the confirm gate.
///
/// The load-bearing tests here assert that nothing happened: the pantry screen
/// sends no deduction, and an unconfirmed proposal leaves the cupboard alone.
/// The client half of the confirm gate is that no screen calls
/// `confirmPantryDeduction` except the one with a button on it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/api/nuvi_api.dart';
import 'package:nuvi_lifestyle/pantry/deduction_confirm_screen.dart';
import 'package:nuvi_lifestyle/pantry/grocery_list_screen.dart';
import 'package:nuvi_lifestyle/pantry/pantry_screen.dart';

import '../support/fake_api.dart';

/// `NuviPage` is a `ListView` and builds lazily; the default 800×600 window
/// leaves later rows unbuilt, so a finder would report "not found" for a layout
/// reason rather than a real one.
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
  PantryItem(
    id: 'item-2',
    displayName: "amma's chutney",
    quantityOnHand: '300.000',
    unit: 'g',
    bestBeforeOn: '2026-03-01',
    daysUntilDate: 1,
    isUseSoon: true,
  ),
];

final _reconciliation = GroceryReconciliation(
  householdId: 'h1',
  start: '2026-03-01',
  end: '2026-03-01',
  disclaimer: 'Quantities are unreviewed estimates. No prices are shown.',
  groceries: const [
    ReconciledGrocery(
      canonicalKey: 'sambar-rice-base',
      name: 'Sambar rice base',
      requiredGrams: '100.0',
      onHandGrams: '40.0',
      netToBuyGrams: '60.0',
      surplusGrams: '0.0',
      members: [
        GroceryMemberLine(
          memberId: 'm1',
          memberReference: 'M1',
          grams: '100.0',
          goalKey: 'maintenance',
          excludedAllergenTags: ['gluten'],
        ),
      ],
    ),
    ReconciledGrocery(
      canonicalKey: 'upma-base',
      name: 'Upma base',
      requiredGrams: '100.0',
      onHandGrams: '250.0',
      netToBuyGrams: '0.0',
      surplusGrams: '150.0',
      isFullyStocked: true,
    ),
  ],
  useSoon: const ["amma's chutney"],
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

void main() {
  group('pantry screen', () {
    testWidgets('shows a spinner while the pantry is in flight', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(delay: const Duration(milliseconds: 50))
        ..pantry = _items;

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders the server quantity verbatim', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = _items;

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      // Not "250" or "250.0" — a widget that parsed this to a double and
      // reprinted it would fail here, which is the point.
      expect(find.text('250.000 g'), findsWidgets);
    });

    testWidgets('surfaces a use-soon item without offering to discard it', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = _items;

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Use soon'), findsOneWidget);
      expect(find.textContaining('throws'), findsOneWidget);
      expect(find.textContaining('Discard'), findsNothing);
      expect(find.textContaining('Throw away'), findsNothing);
    });

    testWidgets('an adjustment sends a delta, never an absolute quantity', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = _items;

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pantry-bought-item-1')).first);
      await tester.pumpAndSettle();

      expect(api.writes, contains('adjust:item-1:100:purchase'));
    });

    testWidgets('the pantry screen never sends a deduction', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantry = _items;

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        api.writes.where((w) => w.startsWith('confirmDeduction')),
        isEmpty,
        reason: 'only the confirm screen may deduct stock',
      );
    });

    testWidgets('offline says offline, not "something went wrong"', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..pantryFailure = const SocketException('no route');

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a refusal offers no retry button', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..pantryFailure = ApiException(403, 'nope');

      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: api, householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('do not have access'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('an empty pantry says what would fill it', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PantryScreen(api: FakeNuviApi(), householdId: 'h1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing recorded yet'), findsOneWidget);
    });
  });

  group('grocery list', () {
    Widget host(FakeNuviApi api) => MaterialApp(
      home: GroceryListScreen(
        api: api,
        householdId: 'h1',
        start: '2026-03-01',
        end: '2026-03-01',
      ),
    );

    testWidgets('shows required, on-hand and net-to-buy together', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..reconciliation_ = _reconciliation;

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.text('Needed'), findsWidgets);
      expect(find.text('Already have'), findsWidgets);
      expect(find.text('Buy'), findsWidgets);
      expect(find.text('100.0 g'), findsWidgets);
      expect(find.text('40.0 g'), findsWidgets);
      expect(find.text('60.0 g'), findsWidgets);
    });

    testWidgets('separates what to buy from what is already covered', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..reconciliation_ = _reconciliation;

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.text('To buy'), findsOneWidget);
      expect(find.text('Already covered'), findsOneWidget);
    });

    testWidgets('keeps per-member detail rather than one merged figure', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..reconciliation_ = _reconciliation;

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('M1: 100.0 g'), findsOneWidget);
      expect(find.textContaining('avoids gluten'), findsOneWidget);
    });

    testWidgets('carries the unreviewed-estimate disclaimer', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..reconciliation_ = _reconciliation;

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('unreviewed estimates'), findsOneWidget);
    });

    testWidgets('shows no price anywhere', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..reconciliation_ = _reconciliation;

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('offline is distinguished from an error', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..reconciliationFailure = const SocketException('down');

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsOneWidget);
    });
  });

  group('deduction confirm flow', () {
    Widget host(FakeNuviApi api) => MaterialApp(
      home: DeductionConfirmScreen(api: api, householdId: 'h1'),
    );

    testWidgets('shows what it proposes to remove and what is there', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = [_proposal];

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.text('Upma (breakfast)'), findsOneWidget);
      expect(find.text('−100.000 g'), findsOneWidget);
      expect(find.text('250.000 g'), findsOneWidget);
    });

    testWidgets('nothing is sent until the user confirms', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = [_proposal];

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(api.writes, isEmpty);
    });

    testWidgets('confirming sends exactly one confirmation', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = [_proposal];

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      await tester.pumpAndSettle();

      expect(api.writes, ['confirmDeduction:prop-1']);
    });

    testWidgets('declining sends a rejection and no deduction', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = [_proposal];

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reject-prop-1')));
      await tester.pumpAndSettle();

      expect(api.writes, ['rejectDeduction:prop-1']);
      expect(
        api.writes.where((w) => w.startsWith('confirmDeduction')),
        isEmpty,
      );
    });

    testWidgets('"not this time" is offered as an equal option', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..deductions = [_proposal];

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.text('Not this time'), findsOneWidget);
      expect(find.text('Update pantry'), findsOneWidget);
    });

    testWidgets('a shortfall is explained rather than hidden', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..deductions = const [
          PantryDeductionProposal(
            id: 'prop-2',
            status: 'proposed',
            summary: 'Sambar Rice (lunch)',
            lines: [
              PantryDeductionLine(
                itemId: 'item-3',
                itemName: 'sambar mix',
                quantity: '100.000',
                unit: 'g',
                availableQuantity: '40.000',
                exceedsAvailable: true,
              ),
            ],
          ),
        ];

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('more than we have recorded'), findsOneWidget);
    });

    testWidgets('a failed confirm surfaces a message and does not clear', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..deductions = [_proposal]
        ..decideDeductionFailure = const SocketException('down');

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-prop-1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsOneWidget);
    });
  });
}
