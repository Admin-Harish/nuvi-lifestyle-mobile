/// The progress dashboard.
///
/// Most of these tests assert an absence. A composite score, a grade, a penalty
/// for a broken streak and a ranking between household members are all things
/// this screen must not grow, and the only thing that will notice if one
/// appears is a test that fails when it does.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/progress/progress_dashboard_screen.dart';

import '../support/fake_api.dart';

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _trends = ProgressTrends(
  adherence: '0.7500',
  hydrationConsistency: '0.5000',
  mealRegularity: '0.9000',
  loggingConsistency: '0.8000',
  macroConsistency: '0.6000',
);

const _representative = MemberProgress(
  memberId: 'm1',
  memberReference: 'M1',
  start: '2026-03-01',
  end: '2026-03-14',
  trends: _trends,
  disclaimer: 'These figures are unreviewed estimates.',
  daysInWindow: 14,
  daysLogged: 10,
  isRepresentative: true,
  loggingStreakDays: 4,
  longestLoggingStreakDays: 6,
);

const _sparse = MemberProgress(
  memberId: 'm1',
  memberReference: 'M1',
  start: '2026-03-01',
  end: '2026-03-14',
  trends: _trends,
  disclaimer: 'These figures are unreviewed estimates.',
  daysInWindow: 14,
  daysLogged: 2,
  loggingStreakDays: 1,
  longestLoggingStreakDays: 1,
);

Widget _host(FakeNuviApi api) => MaterialApp(
  home: ProgressDashboardScreen(
    api: api,
    memberId: 'm1',
    start: '2026-03-01',
    end: '2026-03-14',
  ),
);

void main() {
  group('member progress', () {
    testWidgets('shows a spinner while the window is in flight', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi(delay: const Duration(milliseconds: 50))
        ..memberProgress_ = _representative;

      await tester.pumpWidget(_host(api));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('renders the five trends as separate meters', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..memberProgress_ = _representative;

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.text('Followed the plan'), findsOneWidget);
      expect(find.text('Met your water target'), findsOneWidget);
      expect(find.text('Meals accounted for'), findsOneWidget);
      expect(find.text('Days with an entry'), findsOneWidget);
      expect(find.text('Days close to plan'), findsOneWidget);
    });

    testWidgets('shows no composite score or grade', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..memberProgress_ = _representative;

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      for (final banned in ['Score', 'Grade', 'Rating', 'Overall', 'Total']) {
        expect(
          find.textContaining(banned),
          findsNothing,
          reason: '$banned would turn a description into a judgement',
        );
      }
    });

    testWidgets('uses no shaming language', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..memberProgress_ = _representative;

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      for (final banned in [
        'Missed',
        'Failed',
        'Compliance',
        'Poor',
        'Penalty',
      ]) {
        expect(find.textContaining(banned), findsNothing);
      }
    });

    testWidgets('reports a streak as a fact with nothing attached', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..memberProgress_ = _representative;

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.text('Current run of logged days'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('at risk'), findsNothing);
      expect(find.textContaining('Keep it up'), findsNothing);
    });

    testWidgets('an under-logged window is not drawn as a trend', (
      tester,
    ) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..memberProgress_ = _sparse;

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('not-representative')), findsOneWidget);
      expect(find.text('Followed the plan'), findsNothing);
    });

    testWidgets('carries the unreviewed-estimate disclaimer', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()..memberProgress_ = _representative;

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('unreviewed estimates'), findsOneWidget);
    });

    testWidgets('offline is distinguished from an error', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..memberProgressFailure = const SocketException('down');

      await tester.pumpWidget(_host(api));
      await tester.pumpAndSettle();

      expect(find.textContaining('offline'), findsOneWidget);
    });
  });

  group('household progress', () {
    Widget host(FakeNuviApi api) => MaterialApp(
      home: HouseholdProgressScreen(
        api: api,
        householdId: 'h1',
        start: '2026-03-01',
        end: '2026-03-14',
      ),
    );

    testWidgets('shows one row per member with totals only', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..householdProgress_ = const HouseholdProgress(
          householdId: 'h1',
          start: '2026-03-01',
          end: '2026-03-14',
          disclaimer: 'unreviewed estimates',
          members: [_representative],
        );

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      expect(find.text('M1'), findsOneWidget);
      expect(find.text('Days logged'), findsOneWidget);
      // No per-day breakdown reaches a shared screen.
      expect(find.text('Followed the plan'), findsNothing);
    });

    testWidgets('ranks nobody', (tester) async {
      _useTallSurface(tester);
      final api = FakeNuviApi()
        ..householdProgress_ = const HouseholdProgress(
          householdId: 'h1',
          start: '2026-03-01',
          end: '2026-03-14',
          disclaimer: 'unreviewed estimates',
          members: [_representative],
        );

      await tester.pumpWidget(host(api));
      await tester.pumpAndSettle();

      for (final banned in ['Best', 'Worst', 'Leader', 'Rank', '1st']) {
        expect(find.textContaining(banned), findsNothing);
      }
    });

    testWidgets('an empty household says so', (tester) async {
      _useTallSurface(tester);

      await tester.pumpWidget(host(FakeNuviApi()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing to show'), findsOneWidget);
    });
  });
}
