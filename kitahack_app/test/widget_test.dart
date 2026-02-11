import 'package:flutter_test/flutter_test.dart';
import 'package:kitahack_app/main.dart'; // Import your new main file

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const ResilienceBuilderApp());

    // 2. Verify that the app title is present.
    // This confirms the HomeScreen loaded successfully.
    expect(find.text('ResilienceBuilder (KL)'), findsOneWidget);
  });
}