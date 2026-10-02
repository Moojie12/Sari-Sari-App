import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sari_sari/users/customer_db/tutorial/customer_tutorial_overlay.dart';
import 'package:sari_sari/users/customer_db/tutorial/customer_tutorial_service.dart';
import 'package:sari_sari/users/customer_db/tutorial/customer_tutorial_step.dart';
import 'package:sari_sari/users/customer_db/profile/customer_profile_page.dart';
import 'package:sari_sari/users/customer_db/customer_dashboard.dart';

void main() {
  group('Customer Tutorial Service & Model Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CustomerTutorialService.setMockSeenTutorial(null);
    });

    test('CustomerTutorialStep defaultSteps contains exactly the 8 required features', () {
      final steps = CustomerTutorialStep.defaultSteps;
      expect(steps.length, 8);

      final expectedIds = [
        'home',
        'search',
        'add_to_cart',
        'cart',
        'checkout',
        'orders',
        'notifications',
        'profile',
      ];

      for (int i = 0; i < expectedIds.length; i++) {
        expect(steps[i].id, expectedIds[i]);
        expect(steps[i].title.isNotEmpty, true);
        expect(steps[i].description.isNotEmpty, true);
      }

      // Check specific titles matching requirements
      expect(steps[0].title, 'Home');
      expect(steps[1].title, contains('Search'));
      expect(steps[2].title, 'Add to Cart');
      expect(steps[3].title, 'Cart');
      expect(steps[4].title, 'Checkout');
      expect(steps[5].title, contains('Orders'));
      expect(steps[6].title, 'Notifications');
      expect(steps[7].title, 'Profile');
    });

    test('CustomerTutorialService mock control and state updates work properly', () async {
      CustomerTutorialService.setMockSeenTutorial(false);
      expect(await CustomerTutorialService.hasSeenTutorial(), false);

      await CustomerTutorialService.markTutorialCompleted();
      expect(await CustomerTutorialService.hasSeenTutorial(), true);

      await CustomerTutorialService.resetTutorial();
      expect(await CustomerTutorialService.hasSeenTutorial(), false);
    });
  });

  group('Customer Tutorial Overlay Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CustomerTutorialService.setMockSeenTutorial(null);
    });

    testWidgets('Renders Step 1 with Next and Skip, but no Back button',
        (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerTutorialOverlay(
              enablePulse: false,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Verify Step 1 content
      expect(find.text('Step 1 of 8'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.byKey(const Key('tutorial_skip_button')), findsOneWidget);
      expect(find.byKey(const Key('tutorial_next_button')), findsOneWidget);
      expect(find.byKey(const Key('tutorial_back_button')), findsNothing);
      expect(find.byKey(const Key('tutorial_finish_button')), findsNothing);
      expect(dismissed, false);
    });

    testWidgets('Next button advances step and shows Back button on Step 2',
        (tester) async {
      int changedStep = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerTutorialOverlay(
              enablePulse: false,
              onDismiss: () {},
              onStepChanged: (step) => changedStep = step,
            ),
          ),
        ),
      );

      // Tap Next
      await tester.tap(find.byKey(const Key('tutorial_next_button')));
      await tester.pumpAndSettle();

      expect(changedStep, 1);
      expect(find.text('Step 2 of 8'), findsOneWidget);
      expect(find.text('Products / Search'), findsOneWidget);
      expect(find.byKey(const Key('tutorial_back_button')), findsOneWidget);
      expect(find.byKey(const Key('tutorial_next_button')), findsOneWidget);

      // Tap Back
      await tester.tap(find.byKey(const Key('tutorial_back_button')));
      await tester.pumpAndSettle();

      expect(changedStep, 0);
      expect(find.text('Step 1 of 8'), findsOneWidget);
      expect(find.byKey(const Key('tutorial_back_button')), findsNothing);
    });

    testWidgets('Skip button marks tutorial completed and dismisses overlay',
        (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerTutorialOverlay(
              enablePulse: false,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(await CustomerTutorialService.hasSeenTutorial(), false);

      await tester.tap(find.byKey(const Key('tutorial_skip_button')));
      await tester.pumpAndSettle();

      expect(dismissed, true);
      expect(await CustomerTutorialService.hasSeenTutorial(), true);
    });

    testWidgets('Reaching last step (Step 8: Profile) shows Finish button and completes tutorial',
        (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerTutorialOverlay(
              enablePulse: false,
              initialStep: 7, // Step 8 (0-indexed 7)
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Step 8 of 8'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byKey(const Key('tutorial_back_button')), findsOneWidget);
      expect(find.byKey(const Key('tutorial_next_button')), findsNothing);
      expect(find.byKey(const Key('tutorial_finish_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tutorial_finish_button')));
      await tester.pumpAndSettle();

      expect(dismissed, true);
      expect(await CustomerTutorialService.hasSeenTutorial(), true);
    });

    testWidgets('All 8 steps can be navigated through sequentially',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerTutorialOverlay(
              enablePulse: false,
              onDismiss: () {},
            ),
          ),
        ),
      );

      final titles = [
        'Home',
        'Products / Search',
        'Add to Cart',
        'Cart',
        'Checkout',
        'Orders / Delivery Tracking',
        'Notifications',
        'Profile',
      ];

      for (int i = 0; i < titles.length; i++) {
        expect(find.text('Step ${i + 1} of 8'), findsOneWidget);
        expect(find.text(titles[i]), findsOneWidget);

        if (i < titles.length - 1) {
          await tester.tap(find.byKey(const Key('tutorial_next_button')));
          await tester.pumpAndSettle();
        }
      }

      expect(find.byKey(const Key('tutorial_finish_button')), findsOneWidget);
    });
  });

  group('Profile Page View Tutorial Option Tests', () {
    testWidgets('CustomerProfilePage contains View Tutorial menu option',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerProfilePage(),
        ),
      );

      // Let skeleton settle if needed
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('View Tutorial'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });
  });

  group('CustomerDashboard Tutorial Launch Tests', () {
    testWidgets('CustomerDashboard can trigger tutorial via startTutorial()',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      CustomerTutorialService.setMockSeenTutorial(true); // Don't auto-launch

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerDashboard(key: CustomerDashboard.dashboardKey),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1500));

      // Initially tutorial overlay is not shown
      expect(find.byType(CustomerTutorialOverlay), findsNothing);

      // Programmatically start tutorial (like tapping "View Tutorial" in Profile)
      CustomerDashboard.dashboardKey.currentState?.startTutorial();
      await tester.pump(const Duration(milliseconds: 100));

      // Tutorial overlay is now active
      expect(find.byType(CustomerTutorialOverlay), findsOneWidget);
      expect(find.text('Step 1 of 8'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CustomerTutorialOverlay),
          matching: find.text('Home'),
        ),
        findsOneWidget,
      );

      // Cleanly dismiss before test ends
      CustomerDashboard.dashboardKey.currentState?.dismissTutorial();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Customer Tutorial Positioning Tests', () {
    testWidgets('Spotlight accurately targets mounted widget position',
        (tester) async {
      final targetKey = GlobalKey();

      final customStep = CustomerTutorialStep(
        id: 'search',
        title: 'Search',
        description: 'Test search target',
        icon: Icons.search,
        targetKey: targetKey,
        padding: const EdgeInsets.all(4.0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 180,
                  left: 30,
                  width: 320,
                  height: 48,
                  child: Container(
                    key: targetKey,
                    color: Colors.blue,
                  ),
                ),
                Positioned.fill(
                  child: CustomerTutorialOverlay(
                    enablePulse: false,
                    steps: [customStep],
                    onDismiss: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final state = tester.state<CustomerTutorialOverlayState>(
        find.byType(CustomerTutorialOverlay),
      );
      final rect = state.calculateTargetRectForTest(tester.element(find.byType(CustomerTutorialOverlay)), customStep);

      // Verify the target rect matches the mounted widget's actual coordinates + padding
      expect(rect.left, 30 - 4.0);
      expect(rect.top, 180 - 4.0);
      expect(rect.width, 320 + 8.0);
      expect(rect.height, 48 + 8.0);
    });
  });
}
