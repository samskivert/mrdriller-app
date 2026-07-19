import 'package:flutter_test/flutter_test.dart';

import 'package:mrdriller/data/drills.dart' as data;
import 'package:mrdriller/main.dart';

void main() {
  testWidgets('Menu screen shows the title, a Drills link, and Pattern Trainer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MrDrillerApp());
    await tester.pumpAndSettle();

    expect(find.text('Mr. Driller'), findsWidgets);
    expect(find.text('Drills'), findsOneWidget);
    expect(find.text('Pattern Trainer'), findsOneWidget);
  });

  testWidgets('Tapping Drills opens a screen listing at least one drill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MrDrillerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drills'));
    await tester.pumpAndSettle();

    expect(find.text('Drills'), findsWidgets); // header title now, plus the nav link behind it
    expect(find.text(data.drills.first.title), findsOneWidget);
  });
}
