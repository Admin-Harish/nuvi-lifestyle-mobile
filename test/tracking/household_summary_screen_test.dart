/// The household summary.
///
/// The load-bearing test in this file is
/// `no member row carries a dish name or a label`. Everything else exists to
/// make that one meaningful: the screen renders totals, so a payload that
/// somehow arrived carrying one member's food would have nowhere to put it —
/// and this asserts the rendered tree agrees.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/api/nuvi_api.dart';
import 'package:nuvi_lifestyle/tracking/household_summary_screen.dart';

import '../support/fake_api.dart';

Widget _host(FakeNuviApi api) => MaterialApp(
  home: HouseholdSummaryScreen(
    api: api,
    householdId: 'household-1',
    date: '2026-03-01',
  ),
);

/// A tall test surface.
///
/// `NuviPage` is a `ListView`, which builds lazily: on the default 800×600
/// test window the planned dishes and the disclaimer sit below the fold and
/// are never constructed, so a finder for them reports "not found" for a
/// layout reason rather than a real one. A tall viewport puts the whole page
/// in the tree, which is what these tests are actually about.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('loading', () {
    testWidgets('shows a spinner while the summary is in flight', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(delay: const Duration(milliseconds: 50));

      await tester.pumpWidget(_host(api));
      await tester.pump();

      expect(find.byKey(const Key('household-loading')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('household-loading')), findsNothing);
    });
  });

  group('totals', () {
    testWidgets('renders the household total and the member count', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('household-totals')), findsOneWidget);
      expect(find.text('200 / 900 kcal'), findsOneWidget);
      expect(find.textContaining('2 members'), findsOneWidget);
    });

    testWidgets('renders one row per member with their own figures', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('household-member-M1')), findsOneWidget);
      expect(find.byKey(const Key('household-member-M2')), findsOneWidget);
      // Each member's own target, not the household's, and not each other's.
      expect(find.text('200 / 600 kcal'), findsOneWidget);
      expect(find.text('0 / 300 kcal'), findsOneWidget);
    });

    testWidgets('the singular is used for a household of one', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        householdSummary_: sampleHouseholdSummary(memberCount: 1),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 member ·'), findsOneWidget);
    });

    testWidgets('the unreviewed-figures disclaimer is shown', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('household-disclaimer')), findsOneWidget);
    });
  });

  group('isolation', () {
    testWidgets('no member row carries a dish name or a food label', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      // The dishes the API-suite fixture puts on these members' plans. None of
      // them is sent to this endpoint, and none may appear on this screen.
      for (final forbidden in const ['Upma', 'Sambar Rice', 'Poha', 'laddoo']) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: '$forbidden is one member\'s food and must not be here',
        );
      }
    });

    testWidgets('shows only the members the server sent', (tester) async {
      _useTallSurface(tester);

      /// A caregiver granted one of two siblings is sent one row. The screen
      /// renders what it is sent and has no count of its own that would hint
      /// at the member it cannot see.
      final api = FakeNuviApi(
        householdSummary_: sampleHouseholdSummary(memberCount: 1),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('household-member-M1')), findsOneWidget);
      expect(find.byKey(const Key('household-member-M2')), findsNothing);
      expect(find.textContaining('Aditya'), findsNothing);
    });
  });

  group('failure states', () {
    testWidgets('offline says offline', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        householdSummaryFailure: SocketException('no route to host'),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('household-offline')), findsOneWidget);
      expect(find.byKey(const Key('household-error')), findsNothing);
    });

    testWidgets('a server error is not reported as being offline', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        householdSummaryFailure: ApiException(500, 'boom'),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('household-error')), findsOneWidget);
      expect(find.byKey(const Key('household-offline')), findsNothing);
    });

    testWidgets('a retry that succeeds shows the summary', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        householdSummaryFailure: SocketException('no route to host'),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();
      api.householdSummaryFailure = null;
      await tester.tap(find.byKey(const Key('household-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('household-totals')), findsOneWidget);
    });

    testWidgets('an empty roster gets a sentence, not a blank page', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        householdSummary_: const HouseholdDailySummary(
          householdId: 'household-1',
          date: '2026-03-01',
          memberCount: 0,
          target: Macros(
            energyKcal: '0',
            proteinG: '0',
            carbohydrateG: '0',
            fatG: '0',
            fibreG: '0',
          ),
          consumed: Macros(
            energyKcal: '0',
            proteinG: '0',
            carbohydrateG: '0',
            fatG: '0',
            fibreG: '0',
          ),
          waterTargetMl: 0,
          waterConsumedMl: 0,
          members: [],
          disclaimer: '',
        ),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('household-empty')), findsOneWidget);
    });
  });
}
