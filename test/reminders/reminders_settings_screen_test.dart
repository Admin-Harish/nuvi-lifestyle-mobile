/// Reminder settings.
///
/// The tests that matter here assert the asymmetry: turning a reminder **off**
/// is one tap, and turning one **on** cannot happen without a named approver.
/// The client cannot route around that — `enableReminder` takes `approvedBy` as
/// a required argument — and these tests prove the screen does not try.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvi_lifestyle/api/models.dart';
import 'package:nuvi_lifestyle/api/nuvi_api.dart';
import 'package:nuvi_lifestyle/reminders/reminders_settings_screen.dart';

import '../support/fake_api.dart';

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _disabled = [
  ReminderSchedule(
    id: 'sched-1',
    memberId: 'm1',
    kind: 'hydration',
    sendAtLocal: '11:00:00',
  ),
  ReminderSchedule(
    id: 'sched-2',
    memberId: 'm1',
    kind: 'meal',
    slot: 'lunch',
    sendAtLocal: '13:00:00',
  ),
];

const _enabled = [
  ReminderSchedule(
    id: 'sched-1',
    memberId: 'm1',
    kind: 'hydration',
    sendAtLocal: '11:00:00',
    isEnabled: true,
    approvedBy: 'Dhanalakshmi (Legal/privacy)',
  ),
];

Widget _host(FakeNuviApi api) => MaterialApp(
  home: RemindersSettingsScreen(api: api, memberId: 'm1'),
);

void main() {
  testWidgets('every schedule renders as off', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _disabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsNWidgets(2));
    expect(find.text('On'), findsNothing);
  });

  testWidgets('the screen states that reminders are off and why', (
    tester,
  ) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _disabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reminders are off'), findsOneWidget);
    expect(find.textContaining('named approver'), findsOneWidget);
    expect(find.textContaining('9am–9pm'), findsOneWidget);
  });

  testWidgets('the enable button says an approver is needed', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _disabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.text('Turn on (needs an approver)'), findsNWidgets(2));
  });

  testWidgets('tapping enable asks who is approving before sending', (
    tester,
  ) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _disabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-sched-1')));
    await tester.pumpAndSettle();

    expect(find.text('Who is approving this?'), findsOneWidget);
    expect(api.writes, isEmpty, reason: 'nothing sent before a name is given');
  });

  testWidgets('cancelling the approver dialog sends nothing', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _disabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-sched-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(api.writes, isEmpty);
  });

  testWidgets('an empty approver name sends nothing', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _disabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-sched-1')));
    await tester.pumpAndSettle();
    // Submit with the field untouched.
    await tester.tap(find.byKey(const Key('approver-submit')));
    await tester.pumpAndSettle();

    expect(api.writes, isEmpty);
  });

  testWidgets('a named approver is sent with the enable', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _disabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-sched-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('approver-field')),
      'Dhanalakshmi (Legal/privacy)',
    );
    await tester.tap(find.byKey(const Key('approver-submit')));
    await tester.pumpAndSettle();

    expect(api.writes, ['enable:sched-1:Dhanalakshmi (Legal/privacy)']);
  });

  testWidgets('turning off asks nothing at all', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _enabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('disable-sched-1')));
    await tester.pumpAndSettle();

    expect(api.writes, ['disable:sched-1']);
  });

  testWidgets('an enabled schedule shows who approved it', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()..schedules = _enabled;

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(
      find.text('Approved by Dhanalakshmi (Legal/privacy)'),
      findsOneWidget,
    );
  });

  testWidgets('a rejected enable surfaces a message', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()
      ..schedules = _disabled
      ..enableFailure = ApiException(400, 'approver required');

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enable-sched-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('approver-field')), 'Someone');
    await tester.tap(find.byKey(const Key('approver-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('went wrong'), findsOneWidget);
  });

  testWidgets('offline is distinguished from an error', (tester) async {
    _useTallSurface(tester);
    final api = FakeNuviApi()
      ..schedulesFailure = const SocketException('no route');

    await tester.pumpWidget(_host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('offline'), findsOneWidget);
  });

  testWidgets('no schedules says so plainly', (tester) async {
    _useTallSurface(tester);

    await tester.pumpWidget(_host(FakeNuviApi()));
    await tester.pumpAndSettle();

    expect(find.textContaining('No reminders are set up'), findsOneWidget);
  });
}
