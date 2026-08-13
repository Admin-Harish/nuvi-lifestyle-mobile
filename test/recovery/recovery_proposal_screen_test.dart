/// The recovery proposal confirm flow.
///
/// The safety assertions:
///
/// * the floor and ceiling are shown alongside the advice, so the guarantee is
///   as visible as the suggestion;
/// * "carry on as I am" exists and is not a hidden dismissal;
/// * nothing is sent until the user picks one of the three;
/// * a clinically gated member sees a referral and **no accept button at all**.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/recovery/recovery_proposal_screen.dart';

import '../support/fake_api.dart';

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _proposal = RecoveryProposal(
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
  rationale:
      'On 2026-03-01 the plan came to 600 kcal and 0 kcal was logged. '
      'Days above plan are never balanced out by reducing a later day.',
  adjustments: [
    RecoveryAdjustment(
      day: '2026-03-02',
      originalTargetKcal: '2000.00',
      proposedTargetKcal: '2100.00',
      deltaKcal: '100.00',
    ),
  ],
);

const _referral = RecoveryProposal(
  id: 'rec-2',
  memberId: 'm1',
  trigger: 'skipped_meals',
  triggerDate: '2026-03-01',
  status: 'clinical_review_required',
  floorKcal: '0.00',
  ceilingKcal: '0.00',
  shortfallKcal: '0.00',
  redistributedKcal: '0.00',
  unrecoveredKcal: '0.00',
  rationale: 'routed to a clinician',
  needsClinician: true,
  referral: ClinicalReferralInfo(
    reason:
        "This member's goal needs review by a qualified clinician, so no "
        'automated recovery plan was generated. Their plan is unchanged.',
    goalKey: 'maternity_trimester_2',
  ),
);

Widget _host(FakeNuviApi api) => MaterialApp(
  home: RecoveryProposalScreen(api: api, memberId: 'm1'),
);

void main() {
  testWidgets('shows the suggested change to the days ahead', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('2026-03-02'), findsOneWidget);
    expect(find.text('2000.00 → 2100.00 kcal'), findsOneWidget);
  });

  testWidgets('shows the floor and ceiling next to the advice', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('Never goes below'), findsOneWidget);
    expect(find.text('1200.00 kcal'), findsOneWidget);
    expect(find.text('Never goes above'), findsOneWidget);
    expect(find.text('2400.00 kcal'), findsOneWidget);
  });

  testWidgets('states the part of the shortfall it does not make up', (
    tester,
  ) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('Not made up'), findsOneWidget);
    expect(find.text('450.00 kcal'), findsOneWidget);
  });

  testWidgets('repeats the no-compensation rule in the rationale', (
    tester,
  ) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('never balanced out'), findsOneWidget);
  });

  testWidgets('offers all three answers', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('Use this suggestion'), findsOneWidget);
    expect(find.text('Carry on as I am'), findsOneWidget);
    expect(find.text("I'll do my own thing"), findsOneWidget);
  });

  testWidgets('nothing is sent until the user answers', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(api.writes, isEmpty);
  });

  testWidgets('accepting sends exactly one accept', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-rec-1')));
    await tester.pumpAndSettle();

    expect(api.writes, ['decideRecovery:rec-1:accept']);
  });

  testWidgets('carrying on sends an override, not a dismissal', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('override-rec-1')));
    await tester.pumpAndSettle();

    expect(api.writes, ['decideRecovery:rec-1:override']);
  });

  testWidgets('replacing sends a replace', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_proposal];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replace-rec-1')));
    await tester.pumpAndSettle();

    expect(api.writes, ['decideRecovery:rec-1:replace']);
  });

  testWidgets('a gated member sees a referral and no accept button', (
    tester,
  ) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_referral];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('This one needs a professional'), findsOneWidget);
    expect(find.textContaining('qualified clinician'), findsOneWidget);
    expect(find.byKey(const Key('accept-rec-2')), findsNothing);
    expect(find.text('Use this suggestion'), findsNothing);
  });

  testWidgets('a referral shows no calorie figures', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveries = const [_referral];

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('kcal'), findsNothing);
  });

  testWidgets('nothing to suggest says the plan is unchanged', (tester) async {
    _useTallSurface(tester);

    await tester.pumpWidget(_host(FakeNuviApi()));
    await tester.pumpAndSettle();

    expect(find.textContaining('plan is unchanged'), findsOneWidget);
  });

  testWidgets('offline is distinguished from an error', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..recoveryFailure = const SocketException('down');

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('offline'), findsOneWidget);
  });

  testWidgets('a failed decision surfaces a message', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()
      ..recoveries = const [_proposal]
      ..decideRecoveryFailure = const SocketException('down');

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-rec-1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('offline'), findsOneWidget);
  });
}
