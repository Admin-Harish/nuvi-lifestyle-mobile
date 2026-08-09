/// The goal catalogue screen.
///
/// The behaviour under test is the client half of the clinical gate: a gated
/// goal must be visible, must be unselectable, and must carry the server's
/// reason rather than one the app invented.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/goals/goal_catalogue_screen.dart';

import '../support/fake_api.dart';

Widget _host(Widget child) => MaterialApp(home: child);

/// The catalogue is a lazy ListView, so a short test viewport would simply not
/// build the tiles further down and a "gated goals are shown" assertion would
/// pass or fail on window height rather than on behaviour.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('wellness goals are selectable', (tester) async {
    final api = FakeNuviApi(goals: sampleGoals());
    await tester.pumpWidget(_host(GoalCatalogueScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Weight loss'), findsOneWidget);

    final checkbox = find.descendant(
      of: find.byKey(const Key('goal-weight_loss')),
      matching: find.byType(CheckboxListTile),
    );
    expect(checkbox, findsOneWidget);

    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(
      tester.widget<CheckboxListTile>(checkbox).value,
      isTrue,
      reason: 'an available goal must be selectable',
    );
  });

  testWidgets('a clinically gated goal is shown but cannot be selected', (
    tester,
  ) async {
    final api = FakeNuviApi(goals: sampleGoals());
    await tester.pumpWidget(_host(GoalCatalogueScreen(api: api)));
    await tester.pumpAndSettle();

    final gated = find.byKey(const Key('goal-diabetes_type_2'));
    await tester.scrollUntilVisible(gated, 200);

    // Visible — hiding it would read as "we don't support this".
    expect(gated, findsOneWidget);
    expect(find.text('Diabetes — type 2'), findsOneWidget);

    // And not a control at all: no checkbox, and the tile is disabled.
    expect(
      find.descendant(of: gated, matching: find.byType(CheckboxListTile)),
      findsNothing,
    );
    final tile = tester.widget<ListTile>(
      find.descendant(of: gated, matching: find.byType(ListTile)),
    );
    expect(tile.enabled, isFalse);
    expect(tile.onTap, isNull);
  });

  testWidgets('every gated goal explains itself in the server\'s words', (
    tester,
  ) async {
    useTallViewport(tester);
    final api = FakeNuviApi(goals: sampleGoals());
    await tester.pumpWidget(_host(GoalCatalogueScreen(api: api)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('needs review by a qualified clinician'),
      findsNWidgets(2),
    );
    expect(find.text('Awaiting review'), findsNWidgets(2));
  });

  testWidgets('the gated section explains that nothing is planned from it', (
    tester,
  ) async {
    final api = FakeNuviApi(goals: sampleGoals());
    await tester.pumpWidget(_host(GoalCatalogueScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goals-gated-explainer')), findsOneWidget);
    expect(
      find.textContaining('nothing will be planned from it'),
      findsOneWidget,
    );
  });

  testWidgets('availability comes from the server, not from the category', (
    tester,
  ) async {
    // If the server ever reports a clinical goal as available, the app renders
    // it as available. The client is not a second gate, and must not pretend
    // to be one — the flag decision belongs to the server alone.
    final api = FakeNuviApi(
      goals: [
        ...sampleGoals().where((goal) => goal.available),
        const GoalCatalogueEntry(
          key: 'diabetes_type_2',
          label: 'Diabetes — type 2',
          category: 'clinical',
          available: true,
          statusIfSelected: 'active',
          reason: '',
          explanation: '',
        ),
      ],
    );
    await tester.pumpWidget(_host(GoalCatalogueScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goals-gated-explainer')), findsNothing);
  });

  testWidgets('a failed load says so without losing the screen', (
    tester,
  ) async {
    final api = FakeNuviApi(goalsFailure: Exception('offline'));
    await tester.pumpWidget(_host(GoalCatalogueScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('goals-error')), findsOneWidget);
  });
}
