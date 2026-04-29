import 'package:flutter_test/flutter_test.dart';
import 'package:digital_mandi/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const DigitalMandiApp());
    expect(find.byType(DigitalMandiApp), findsOneWidget);
  });
}
