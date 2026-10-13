import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sari_sari/shared/tutorial/staff_tutorial_overlay.dart';
import 'package:sari_sari/shared/tutorial/staff_tutorial_service.dart';
import 'package:sari_sari/shared/tutorial/staff_tutorial_step.dart';

void main() {
  group('Staff Tutorial Model & Service Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StaffTutorialService.setMockSeen(seen: null);
    });

    test('StaffTutorialStep contains 5 steps for Owner and 5 steps for Employee', () {
      final ownerSteps = StaffTutorialStep.ownerSteps;
      expect(ownerSteps.length, 5);
      expect(ownerSteps[0].id, 'owner_home');
      expect(ownerSteps[1].id, 'owner_pos');
      expect(ownerSteps[2].id, 'owner_inventory');
      expect(ownerSteps[3].id, 'owner_orders');
      expect(ownerSteps[4].id, 'owner_profile');

      final employeeSteps = StaffTutorialStep.employeeSteps;
      expect(employeeSteps.length, 5);
      expect(employeeSteps[0].id, 'emp_home');
      expect(employeeSteps[1].id, 'emp_pos');
      expect(employeeSteps[2].id, 'emp_inventory');
      expect(employeeSteps[3].id, 'emp_orders');
      expect(employeeSteps[4].id, 'emp_profile');
    });

    test('StaffTutorialService marks owner tutorial completed', () async {
      expect(await StaffTutorialService.hasSeenTutorial(isOwner: true), false);
      await StaffTutorialService.markTutorialCompleted(isOwner: true);
      expect(await StaffTutorialService.hasSeenTutorial(isOwner: true), true);
      // Employee should still be false
      expect(await StaffTutorialService.hasSeenTutorial(isOwner: false), false);
    });

    test('StaffTutorialService marks employee tutorial completed', () async {
      expect(await StaffTutorialService.hasSeenTutorial(isOwner: false), false);
      await StaffTutorialService.markTutorialCompleted(isOwner: false);
      expect(await StaffTutorialService.hasSeenTutorial(isOwner: false), true);
    });
  });

  group('Staff Tutorial Overlay Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      StaffTutorialService.setMockSeen(seen: null);
    });

    testWidgets('Owner tutorial renders step 1 of 5 and can navigate through steps',
        (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffTutorialOverlay(
              isOwner: true,
              enablePulse: false,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Step 1 of 5'), findsOneWidget);
      expect(find.text('Store Dashboard (Home)'), findsOneWidget);
      expect(find.byKey(const Key('staff_tut_next_button')), findsOneWidget);
      expect(find.byKey(const Key('staff_tut_skip_button')), findsOneWidget);
      expect(find.byKey(const Key('staff_tut_back_button')), findsNothing);

      // Next to step 2 (POS)
      await tester.tap(find.byKey(const Key('staff_tut_next_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Step 2 of 5'), findsOneWidget);
      expect(find.text('POS (Point of Sale)'), findsOneWidget);
      expect(find.byKey(const Key('staff_tut_back_button')), findsOneWidget);

      // Skip tutorial
      await tester.tap(find.byKey(const Key('staff_tut_skip_button')));
      await tester.pumpAndSettle();

      expect(dismissed, true);
      expect(await StaffTutorialService.hasSeenTutorial(isOwner: true), true);
    });

    testWidgets('Employee tutorial finishes on last step', (tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffTutorialOverlay(
              isOwner: false,
              initialStep: 4,
              enablePulse: false,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Step 5 of 5'), findsOneWidget);
      expect(find.byKey(const Key('staff_tut_finish_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('staff_tut_finish_button')));
      await tester.pumpAndSettle();

      expect(dismissed, true);
      expect(await StaffTutorialService.hasSeenTutorial(isOwner: false), true);
    });
  });
}
