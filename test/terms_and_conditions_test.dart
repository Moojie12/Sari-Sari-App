import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/shared/widgets/terms_and_conditions_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TermsAndConditionsPage Widget Tests', () {
    testWidgets('Renders Terms & Conditions tab and headers correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TermsAndConditionsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & tabs
      expect(find.text('Terms & Permissions'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsAtLeastNWidgets(1));
      expect(find.text('App Permissions'), findsOneWidget);

      // Verify Terms sections
      expect(find.text('Acceptance of Terms'), findsOneWidget);
      expect(find.text('User Accounts & Security'), findsOneWidget);
      expect(find.text('Ordering & Transactions'), findsOneWidget);
    });

    testWidgets('Switches to App Permissions tab and shows permission items', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TermsAndConditionsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'App Permissions' tab
      await tester.tap(find.text('App Permissions'));
      await tester.pumpAndSettle();

      // Verify permission headers
      expect(find.text('Camera Access'), findsOneWidget);
      expect(find.text('Location (GPS) Access'), findsOneWidget);
      expect(find.text('Storage & Photo Access'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);

      // Verify 'Manage Device Settings' button exists
      expect(find.text('Manage Device Settings'), findsOneWidget);
    });

    testWidgets('Renders modal footer buttons when isModal is true', (WidgetTester tester) async {
      bool accepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TermsAndConditionsPage(
            isModal: true,
            onAccept: () {
              accepted = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify modal buttons
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('I Agree & Accept'), findsOneWidget);

      // Tap Accept
      await tester.tap(find.text('I Agree & Accept'));
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
    });
  });
}
