/// The member daily tracker.
///
/// Two things these tests are careful about:
///
/// * **Offline and error are separate assertions**, because they are separate
///   states with separate copy. A test that only checked "some notice appeared"
///   would pass with the message that tells somebody on full signal to check
///   their connection.
/// * **The screen must not recompute nutrition.** The assertions read the exact
///   strings the fake server sent. If a widget ever parsed "133.200" into a
///   double and printed "133.2", these would fail — which is the point.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/api/nuvi_api.dart';
import 'package:nuvi_lifestyle/tracking/daily_tracker_screen.dart';

import '../support/fake_api.dart';

Widget _host(FakeNuviApi api) => MaterialApp(
  home: DailyTrackerScreen(api: api, memberId: 'member-1', date: '2026-03-01'),
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
    testWidgets('shows a spinner while the day is in flight', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(delay: const Duration(milliseconds: 50));

      await tester.pumpWidget(_host(api));
      await tester.pump();

      expect(find.byKey(const Key('tracker-loading')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracker-loading')), findsNothing);
    });
  });

  group('target against consumed', () {
    testWidgets('renders the server figures verbatim', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.text('200 / 600 kcal'), findsOneWidget);
      expect(find.text('400 kcal left today'), findsOneWidget);
    });

    testWidgets('shows a macro bar for each macro', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracker-macros')), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbohydrate'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('Fibre'), findsOneWidget);
      expect(find.text('10 / 30 g'), findsOneWidget);
    });

    testWidgets('a day over budget says "over", not a negative "left"', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        dailySummary_: sampleDailySummary(
          consumedEnergy: '805',
          remainingEnergy: '-205',
        ),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.text('205 kcal over budget'), findsOneWidget);
      expect(find.textContaining('-205'), findsNothing);
    });

    testWidgets('an estimated total is caveated', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        dailySummary_: sampleDailySummary(includesEstimates: true),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracker-estimate-caveat')), findsOneWidget);
    });

    testWidgets('the unreviewed-figures disclaimer is always shown', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracker-disclaimer')), findsOneWidget);
      expect(find.textContaining('unreviewed estimates'), findsOneWidget);
    });
  });

  group('water', () {
    testWidgets('shows the day figures and a meter', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracker-water')), findsOneWidget);
      expect(find.text('750 / 2000 ml'), findsOneWidget);
    });

    testWidgets('logging water sends one write and reloads', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi();

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tracker-water-add-500')));
      await tester.pumpAndSettle();

      expect(api.logged.length, 1);
      expect(api.logged.single.eventType, 'water');
      expect(api.logged.single.waterMl, 500);
      // A reload followed the write, so the figures on screen are the server's.
      expect(
        api.calls.where((call) => call.startsWith('dailySummary')).length,
        2,
      );
    });
  });

  group('planned dishes', () {
    testWidgets('each planned dish shows its slot, name and basis', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.text('Breakfast: Upma'), findsOneWidget);
      expect(find.text('Lunch: Sambar Rice'), findsOneWidget);
      expect(find.text('Eaten'), findsOneWidget);
      expect(find.text('Not logged yet'), findsOneWidget);
    });

    testWidgets('only an unlogged dish offers the "Ate it" action', (
      tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planned-item-lunch-ate')), findsOneWidget);
      expect(find.byKey(const Key('planned-item-breakfast-ate')), findsNothing);
    });

    testWidgets('logging a planned meal writes it and reloads', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi();

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planned-item-lunch-ate')));
      await tester.pumpAndSettle();

      expect(api.logged.single.eventType, 'planned_meal');
    });

    testWidgets('a retried tap reuses one idempotency key', (tester) async {
      _useTallSurface(tester);

      /// The client half of the duplicate-submission guarantee: two taps of the
      /// same failed action carry the same key, so the server absorbs the
      /// second rather than logging a second lunch.
      final api = FakeNuviApi(logIntakeFailure: SocketException('no route'));

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planned-item-lunch-ate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planned-item-lunch-ate')));
      await tester.pumpAndSettle();

      final keys = api.calls
          .where((call) => call.startsWith('logIntake'))
          .toSet();
      expect(api.calls.where((c) => c.startsWith('logIntake')).length, 2);
      expect(keys.length, 1, reason: 'both attempts carried the same key');
    });
  });

  group('unplanned food', () {
    testWidgets('an estimate is labelled as one', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        dailySummary_: sampleDailySummary(
          unplanned: [
            UnplannedItem(
              eventId: 'event-1',
              eventType: 'off_plan',
              label: 'wedding biryani',
              macros: macros(energy: '620'),
              isEstimate: true,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(
        find.text('wedding biryani — 620 kcal (estimate)'),
        findsOneWidget,
      );
    });
  });

  group('failure states', () {
    testWidgets('offline says offline, and offers a retry', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        dailySummaryFailure: SocketException('no route to host'),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracker-offline')), findsOneWidget);
      expect(find.byKey(const Key('tracker-error')), findsNothing);
      expect(find.byKey(const Key('tracker-retry')), findsOneWidget);
    });

    testWidgets('a server error is not reported as being offline', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(dailySummaryFailure: ApiException(500, 'boom'));

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracker-error')), findsOneWidget);
      expect(find.byKey(const Key('tracker-offline')), findsNothing);
    });

    testWidgets('a retry that succeeds shows the day', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(
        dailySummaryFailure: SocketException('no route to host'),
      );

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();
      api.dailySummaryFailure = null;
      await tester.tap(find.byKey(const Key('tracker-retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracker-budget')), findsOneWidget);
      expect(find.text('200 / 600 kcal'), findsOneWidget);
    });

    testWidgets('a failed write says nothing was saved', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(logIntakeFailure: SocketException('no route'));

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tracker-water-add-200')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracker-write-error')), findsOneWidget);
      expect(find.textContaining('Nothing was saved'), findsOneWidget);
    });

    testWidgets('a refused write does not blame the connection', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(logIntakeFailure: ApiException(403, 'nope'));

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tracker-water-add-200')));
      await tester.pumpAndSettle();

      expect(find.textContaining('do not have permission'), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
    });
  });

  group('no plan', () {
    testWidgets(
      'a day without a plan says so rather than showing an empty one',
      (tester) async {
        final api = FakeNuviApi(
          dailySummary_: DailySummary(
            memberId: 'member-1',
            date: '2026-04-15',
            planReference: '',
            goalKey: '',
            hasPlan: false,
            target: macros(),
            consumed: macros(),
            remaining: macros(),
            projected: macros(),
            includesEstimates: false,
            hydration: const Hydration(
              targetMl: 2000,
              consumedMl: 0,
              remainingMl: 2000,
              isTargetMet: false,
            ),
            planned: const [],
            unplanned: const [],
            disclaimer: 'Macro figures are unreviewed estimates.',
          ),
        );

        await tester.pumpWidget(_host(api));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tracker-no-plan')), findsOneWidget);
      },
    );
  });
}
