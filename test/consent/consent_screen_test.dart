/// The consent screen.
///
/// Two guarantees: draft copy is visibly labelled as draft, and the five
/// purposes are decided separately. Both are things a redesign could quietly
/// undo — a nicer single "I agree" is always tempting — so both are asserted
/// rather than trusted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/consent/consent_screen.dart';

import '../support/fake_api.dart';

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('draft wording is labelled, not presented as final', (
    tester,
  ) async {
    final api = FakeNuviApi(consents: sampleDraftConsents());
    await tester.pumpWidget(_host(ConsentScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent-draft-banner')), findsOneWidget);
    expect(find.textContaining('DRAFT'), findsOneWidget);
    expect(
      find.textContaining('is not the agreement you will be asked to accept'),
      findsOneWidget,
    );
    // And every individual purpose repeats it, so a scrolled-past banner does
    // not leave a row looking approved.
    expect(find.text('Not final — awaiting review.'), findsNWidgets(3));
  });

  testWidgets('approved wording drops the draft banner', (tester) async {
    final api = FakeNuviApi(
      consents: const [
        ConsentSummaryEntry(
          purpose: 'communications',
          granted: false,
          decision: null,
          documentVersion: 2,
          documentStatus: 'approved',
          isPresentable: true,
          withdrawable: true,
        ),
      ],
    );
    await tester.pumpWidget(_host(ConsentScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('consent-draft-banner')), findsNothing);
    expect(find.text('Version 2'), findsOneWidget);
  });

  testWidgets('each purpose is its own switch, never one blanket agreement', (
    tester,
  ) async {
    final api = FakeNuviApi(consents: sampleDraftConsents());
    await tester.pumpWidget(_host(ConsentScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsNWidgets(3));
    expect(find.byKey(const Key('consent-data_processing')), findsOneWidget);
    expect(find.byKey(const Key('consent-communications')), findsOneWidget);
    expect(find.byKey(const Key('consent-health_data')), findsOneWidget);
  });

  testWidgets('granting one purpose leaves the others untouched', (
    tester,
  ) async {
    final api = FakeNuviApi(consents: sampleDraftConsents());
    await tester.pumpWidget(_host(ConsentScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('consent-communications')),
        matching: find.byType(SwitchListTile),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.consentWrites, [('communications', 'granted')]);
    expect(
      api.consentWrites.where((write) => write.$1 != 'communications'),
      isEmpty,
    );
  });

  testWidgets('withdrawing sends a withdrawal, not a deletion', (tester) async {
    final api = FakeNuviApi(consents: sampleDraftConsents());
    await tester.pumpWidget(_host(ConsentScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('consent-health_data')),
        matching: find.byType(SwitchListTile),
      ),
    );
    await tester.pumpAndSettle();

    // Append-only on the server; the client's job is to say "withdrawn"
    // rather than to ask for anything to be removed.
    expect(api.consentWrites, [('health_data', 'withdrawn')]);
  });

  testWidgets('essential consent cannot be toggled off, and says why', (
    tester,
  ) async {
    final api = FakeNuviApi(consents: sampleDraftConsents());
    await tester.pumpWidget(_host(ConsentScreen(api: api)));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.descendant(
        of: find.byKey(const Key('consent-data_processing')),
        matching: find.byType(SwitchListTile),
      ),
    );

    expect(tile.onChanged, isNull);
    expect(find.textContaining('close your account'), findsOneWidget);
  });

  testWidgets('a rejected write is surfaced and nothing is silently dropped', (
    tester,
  ) async {
    final api = FakeNuviApi(
      consents: sampleDraftConsents(),
      consentWriteFailure: Exception('offline'),
    );
    await tester.pumpWidget(_host(ConsentScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('consent-communications')),
        matching: find.byType(SwitchListTile),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('could not save'), findsOneWidget);
    expect(api.consentWrites, isEmpty);
  });
}
