import 'package:flutter_test/flutter_test.dart';
import 'package:macro_snap/app.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroSnapApp());
    expect(find.text('Ready to track?'), findsOneWidget);
  });
}
