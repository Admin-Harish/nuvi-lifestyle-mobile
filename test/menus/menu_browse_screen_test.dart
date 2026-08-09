/// Menu browsing: loading, error, both empty states, and the content itself.
///
/// The empty-state tests carry the most weight. "Awaiting clinical review" and
/// "no menus yet" look the same to a naive implementation and are not the same
/// thing to tell somebody about their own condition.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/menus/menu_browse_screen.dart';

import '../support/fake_api.dart';

const _dish = MenuDish(
  slot: 'breakfast',
  dishName: 'Idli with sambar',
  servingGrams: '260.00',
  macros: Macros(
    energyKcal: '412',
    proteinG: '12.4',
    carbohydrateG: '78.1',
    fatG: '5.2',
    fibreG: '6.1',
  ),
  allergenTags: ['gluten'],
);

const _midMorning = MenuDish(
  slot: 'mid_morning',
  dishName: 'Buttermilk',
  servingGrams: '200.00',
  macros: Macros(
    energyKcal: '78',
    proteinG: '3.9',
    carbohydrateG: '5.8',
    fatG: '4.1',
    fibreG: '0.0',
  ),
  allergenTags: ['dairy'],
);

const _day = MenuDay(
  dayIndex: 1,
  goalKey: 'weight_loss',
  macros: Macros(
    energyKcal: '1712',
    proteinG: '61.2',
    carbohydrateG: '242.0',
    fatG: '44.8',
    fibreG: '26.3',
  ),
  allergenTags: ['dairy', 'gluten'],
  dishes: [_dish, _midMorning],
);

MenuLibrary _library({
  List<MenuDay> days = const [_day],
  MenuLibraryEmptyReason reason = MenuLibraryEmptyReason.none,
  bool gated = false,
}) => MenuLibrary(
  goalKey: 'weight_loss',
  days: days,
  emptyReason: reason,
  isGated: gated,
);

Widget _screen(FakeNuviApi api) =>
    MaterialApp(home: MenuBrowseScreen(api: api, goalKey: 'weight_loss'));

void main() {
  group('states', () {
    testWidgets('shows a spinner while the library is in flight', (
      tester,
    ) async {
      final api = FakeNuviApi(
        menuLibrary_: _library(),
        delay: const Duration(milliseconds: 50),
      );

      await tester.pumpWidget(_screen(api));
      await tester.pump();

      expect(find.byKey(const Key('menu-loading')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-loading')), findsNothing);
    });

    testWidgets('shows one message for any failure, and offers a retry', (
      tester,
    ) async {
      final api = FakeNuviApi(menuFailure: Exception('network is down'));

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu-error')), findsOneWidget);
      expect(find.byKey(const Key('menu-retry')), findsOneWidget);
      // The underlying error is never rendered.
      expect(find.textContaining('network is down'), findsNothing);
    });

    testWidgets('retry asks again, and a recovered server shows content', (
      tester,
    ) async {
      final api = FakeNuviApi(menuFailure: Exception('boom'));

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-error')), findsOneWidget);

      // The whole point of a retry is that the next attempt might work.
      api.menuFailure = null;
      api.menuLibrary_ = _library();

      await tester.tap(find.byKey(const Key('menu-retry')));
      await tester.pumpAndSettle();

      expect(
        api.calls.where((call) => call.startsWith('menuLibrary')).length,
        2,
      );
      expect(find.byKey(const Key('menu-error')), findsNothing);
      expect(find.byKey(const Key('menu-day-1')), findsOneWidget);
    });

    testWidgets('a gated goal says it is awaiting clinical review', (
      tester,
    ) async {
      final api = FakeNuviApi(
        menuLibrary_: _library(
          days: const [],
          reason: MenuLibraryEmptyReason.flagOff,
          gated: true,
        ),
      );

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu-empty-gated')), findsOneWidget);
      expect(find.textContaining('awaiting clinical review'), findsOneWidget);
    });

    testWidgets('an ungenerated library says something different', (
      tester,
    ) async {
      final api = FakeNuviApi(
        menuLibrary_: _library(
          days: const [],
          reason: MenuLibraryEmptyReason.notGenerated,
        ),
      );

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu-empty-none')), findsOneWidget);
      expect(find.textContaining('awaiting clinical review'), findsNothing);
    });
  });

  group('content', () {
    testWidgets('every day shows its own macro rollup', (tester) async {
      final api = FakeNuviApi(menuLibrary_: _library());

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu-day-1')), findsOneWidget);
      expect(
        find.byKey(const Key('menu-day-1-macros')),
        findsOneWidget,
      );
      expect(find.textContaining('1712 kcal'), findsOneWidget);
    });

    testWidgets('every dish shows the weight its macros describe', (
      tester,
    ) async {
      final api = FakeNuviApi(menuLibrary_: _library());

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      // The pairing is the point: energy without a serving weight is not
      // actionable, and this is the assertion that stops one being dropped.
      expect(find.textContaining('260.00 g'), findsOneWidget);
      expect(find.textContaining('412 kcal'), findsOneWidget);
    });

    testWidgets('slot keys are rendered readably', (tester) async {
      final api = FakeNuviApi(menuLibrary_: _library());

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.text('Mid morning'), findsOneWidget);
      expect(find.text('mid_morning'), findsNothing);
    });

    testWidgets('a day lists the allergens it contains', (tester) async {
      final api = FakeNuviApi(menuLibrary_: _library());

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu-day-1-allergens')), findsOneWidget);
      expect(find.textContaining('dairy'), findsWidgets);
    });

    testWidgets('the day count is shown', (tester) async {
      final api = FakeNuviApi(menuLibrary_: _library());

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu-day-count')), findsOneWidget);
      expect(find.text('1 days'), findsOneWidget);
    });

    testWidgets('each dish carries an accessible label', (tester) async {
      final api = FakeNuviApi(menuLibrary_: _library());

      await tester.pumpWidget(_screen(api));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          RegExp('Breakfast: Idli with sambar, 260.00 grams'),
        ),
        findsOneWidget,
      );
    });
  });

  group('macro handling', () {
    test('macros stay strings so exact decimals survive', () {
      const macros = Macros(
        energyKcal: '412',
        proteinG: '12.40',
        carbohydrateG: '78.1',
        fatG: '5.2',
        fibreG: '6.1',
      );

      // 12.40, not 12.4 — the trailing zero is the server's precision and the
      // app must not quietly normalise it away by round-tripping through a
      // double.
      expect(macros.proteinG, '12.40');
      expect(macros.summary, contains('P 12.40 g'));
    });

    test('a missing macro block reads as zero rather than crashing', () {
      final macros = Macros.fromJson(const {});
      expect(macros.energyKcal, '0');
    });

    test('a day with no dishes parses to an empty list', () {
      final day = MenuDay.fromJson(const {'day_index': 4});
      expect(day.dishes, isEmpty);
      expect(day.dayIndex, 4);
    });
  });
}
