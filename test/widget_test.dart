import 'package:flutter_test/flutter_test.dart';
import 'package:jiwoo_app/main.dart';

void main() {
  testWidgets('JiwooApp renders LoginPage when logged out',
      (WidgetTester tester) async {
    await tester.pumpWidget(const JiwooApp());
    expect(find.text('Jiwoo Daily Planner'), findsOneWidget);
  });
}
