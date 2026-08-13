/// Plan list and plan detail: loading, empty, error, and the exclusion notice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/plans/plan_list_screen.dart';

import '../support/fake_api.dart';

const _summary = MealPlanSummary(
  id: 'plan-1',
  reference: 'MP-000001',
  goalKey: 'weight_loss',
  status: 'issued',
  startsOn: '2026-03-01',
  endsOn: '2026-03-07',
);

const _detail = MealPlanDetail(
  summary: _summary,
  macros: Macros(
    energyKcal: '11984',
    proteinG: '428.4',
    carbohydrateG: '1694.0',
    fatG: '313.6',
    fibreG: '184.1',
  ),
  excludedAllergenTags: ['gluten'],
  days: [
    MenuDay(
      dayIndex: 1,
      goalKey: 'weight_loss',
      macros: Macros(
        energyKcal: '1712',
        proteinG: '61.2',
        carbohydrateG: '242.0',
        fatG: '44.8',
        fibreG: '26.3',
      ),
      allergenTags: [],
      dishes: [
        MenuDish(
          slot: 'breakfast',
          dishName: 'Moong pesarattu',
          servingGrams: '190.00',
          macros: Macros(
            energyKcal: '355',
            proteinG: '18.2',
            carbohydrateG: '48.0',
            fatG: '9.1',
            fibreG: '8.4',
          ),
          allergenTags: [],
        ),
      ],
    ),
  ],
);

void main() {
  group('plan list', () {
    testWidgets('shows a spinner while loading', (tester) async {
      final api = FakeNuviApi(
        plans: const [_summary],
        delay: const Duration(milliseconds: 50),
      );

      await tester.pumpWidget(MaterialApp(home: PlanListScreen(api: api)));
      await tester.pump();

      expect(find.byKey(const Key('plans-loading')), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('says what will happen when there are no plans', (
      tester,
    ) async {
      final api = FakeNuviApi(plans: const []);

      await tester.pumpWidget(MaterialApp(home: PlanListScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plans-empty')), findsOneWidget);
      expect(
        find.textContaining('once your dietitian assigns it'),
        findsOneWidget,
      );
    });

    testWidgets('shows one message on failure and offers a retry', (
      tester,
    ) async {
      final api = FakeNuviApi(plansFailure: Exception('500 from upstream'));

      await tester.pumpWidget(MaterialApp(home: PlanListScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plans-error')), findsOneWidget);
      expect(find.textContaining('500 from upstream'), findsNothing);

      api.plansFailure = null;
      api.plans = const [_summary];

      await tester.tap(find.byKey(const Key('plans-retry')));
      await tester.pumpAndSettle();

      expect(api.calls.where((call) => call == 'mealPlans').length, 2);
      expect(find.byKey(const Key('plan-MP-000001')), findsOneWidget);
    });

    testWidgets('lists a plan with its reference and status', (tester) async {
      final api = FakeNuviApi(plans: const [_summary]);

      await tester.pumpWidget(MaterialApp(home: PlanListScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plan-MP-000001')), findsOneWidget);
      expect(find.text('MP-000001'), findsOneWidget);
      expect(find.byKey(const Key('plan-MP-000001-status')), findsOneWidget);
    });
  });

  group('plan detail', () {
    testWidgets('shows the exclusions the plan was built against', (
      tester,
    ) async {
      final api = FakeNuviApi(planDetail: _detail);

      await tester.pumpWidget(
        MaterialApp(
          home: PlanDetailScreen(api: api, planId: 'plan-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Months later, "why is there no wheat in this?" should be answerable
      // from the plan itself rather than from a support ticket.
      expect(find.byKey(const Key('plan-detail-exclusions')), findsOneWidget);
      expect(find.textContaining('Built avoiding: gluten'), findsOneWidget);
    });

    testWidgets('shows per-day and per-dish weight and macros', (tester) async {
      final api = FakeNuviApi(planDetail: _detail);

      await tester.pumpWidget(
        MaterialApp(
          home: PlanDetailScreen(api: api, planId: 'plan-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plan-day-1-macros')), findsOneWidget);
      expect(find.byKey(const Key('plan-day-1-breakfast')), findsOneWidget);
      expect(find.textContaining('190.00 g, 355 kcal'), findsOneWidget);
    });

    testWidgets('shows an error state rather than a blank page', (
      tester,
    ) async {
      final api = FakeNuviApi(planDetailFailure: Exception('gone'));

      await tester.pumpWidget(
        MaterialApp(
          home: PlanDetailScreen(api: api, planId: 'plan-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('plan-detail-error')), findsOneWidget);
    });

    testWidgets('shows a spinner while loading', (tester) async {
      final api = FakeNuviApi(
        planDetail: _detail,
        delay: const Duration(milliseconds: 50),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PlanDetailScreen(api: api, planId: 'plan-1'),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('plan-detail-loading')), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
