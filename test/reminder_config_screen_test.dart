import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/screens/reminder_config_screen.dart';
import 'package:mrdriller/state/reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Opens the screen on top of a stand-in for the plan screen (which it returns to when done).
Future<void> _open(
  WidgetTester tester,
  Size size, {
  int? editIndex,
  ReminderConfig? reminder,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: '/daily-practice',
      routes: {
        '/daily-practice': (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ReminderConfigScreen(editIndex: editIndex, initialReminder: reminder),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      },
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

const _reminder = ReminderConfig(id: 1, hour: 19, minute: 5, days: {6, 7});

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await reminders.load();
    // (Loading from empty storage doesn't clear out what a previous test left behind.)
    while (reminders.entries.isNotEmpty) {
      reminders.removeAt(0);
    }
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(1280, 800)]) {
    testWidgets('adding and editing both lay out without errors on a $size screen', (tester) async {
      await _open(tester, size);
      expect(tester.takeException(), isNull);
      await _open(tester, size, editIndex: 0, reminder: _reminder);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('DELETE'), findsOneWidget);
    });
  }

  testWidgets('ADD adds the reminder, on the days picked', (tester) async {
    await _open(tester, const Size(390, 844));
    await tester.tap(find.text('Weekends'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('ADD'));
    await tester.pumpAndSettle();
    expect(reminders.entries, hasLength(1));
    expect(reminders.entries.single.days, {6, 7});
    expect(find.byType(ReminderConfigScreen), findsNothing);
  });

  testWidgets("can't be saved without any days picked", (tester) async {
    await _open(tester, const Size(390, 844));
    await tester.tap(find.text('Weekdays'));
    await tester.pumpAndSettle();
    for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      await tester.tap(find.bySemanticsLabel(day));
      await tester.pumpAndSettle();
    }
    expect(find.text('Pick at least one day.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('ADD'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(reminders.entries, isEmpty);
    expect(find.byType(ReminderConfigScreen), findsOneWidget);
  });

  testWidgets('DELETE removes the reminder, once confirmed', (tester) async {
    reminders.add(_reminder);
    await _open(tester, const Size(390, 844), editIndex: 0, reminder: _reminder);
    await tester.tap(find.bySemanticsLabel('DELETE'));
    await tester.pumpAndSettle();
    expect(find.text('DELETE REMINDER?'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('DELETE').last);
    await tester.pumpAndSettle();
    expect(reminders.entries, isEmpty);
  });

  testWidgets('tapping the time opens the (themed) time picker', (tester) async {
    await _open(tester, const Size(390, 844));
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Time: ')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
  });
}
