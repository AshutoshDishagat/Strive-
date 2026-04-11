// Flutter
// info
// WidgetTester
// utility
// WidgetTester
// properties

import 'package:flutter_test/flutter_test.dart';

import 'package:strive1/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // trigger
    await tester.pumpWidget(const StriveApp());

    // Verify
    expect(find.text('LIVE MONITORING ACTIVE'), findsOneWidget);
  });
}
