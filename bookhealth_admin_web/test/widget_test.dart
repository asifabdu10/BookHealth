import 'package:flutter_test/flutter_test.dart';
import 'package:bookhealth_admin_web/main.dart';

void main() {
  testWidgets('Admin Portal basic UI test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: Since main() initializes Firebase, we might need a mock for a full test,
    // but here we are just correcting the class name.
    await tester.pumpWidget(const AdminWebPortal());

    // Verify that our auth screen text is present.
    expect(find.text('BookHealth Admin Portal'), findsOneWidget);
    expect(find.text('Login to Admin'), findsOneWidget);

    // Verify that we have the login button.
    expect(find.text('Access Dashboard'), findsOneWidget);
  });
}
