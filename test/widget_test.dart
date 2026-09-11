import 'package:flutter_test/flutter_test.dart';

import 'package:dixit_motors_management_app/main.dart';

void main() {
  testWidgets('Dixit Motors app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DixitMotorsApp());
    expect(find.text('DIXIT MOTORS'), findsWidgets);
  });
}
