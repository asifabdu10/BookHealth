import 'package:flutter_test/flutter_test.dart';
import 'package:bookhealth_lab_web/main.dart';

void main() {
  testWidgets('Lab Hub basic UI test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LabWebPortal());

    // Verify that our lab technician portal text is present.
    expect(find.text('Lab Technician Portal'), findsOneWidget);
    expect(find.text('Lab Login'), findsOneWidget);

    // Verify that we have the login button.
    expect(find.text('Login to Portal'), findsOneWidget);
  });
}
