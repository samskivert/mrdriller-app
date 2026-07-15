import 'package:flutter_test/flutter_test.dart';

import 'package:mrdriller/main.dart';

void main() {
  testWidgets('Menu screen shows the title and at least one drill', (WidgetTester tester) async {
    await tester.pumpWidget(const MrDrillerApp());
    await tester.pumpAndSettle();

    expect(find.text('Mr. Driller'), findsWidgets);
    expect(find.text('Pattern Trainer'), findsOneWidget);
  });
}
