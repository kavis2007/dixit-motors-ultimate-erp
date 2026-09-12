import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('Dixit Motors welcome and dashboard smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DixitMotorsApp());

    // Startup splash
    expect(find.text('WELCOME TO DIXIT MOTORS'), findsOneWidget);
    expect(find.text('Dixit Motors Car Workshop'), findsOneWidget);

    // Wait for splash to finish.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    // Dashboard
    expect(find.text('Workshop Command Center'), findsOneWidget);
  });
}
