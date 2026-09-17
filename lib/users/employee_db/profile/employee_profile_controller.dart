import 'package:flutter/foundation.dart';

import 'employee_profile_model.dart';

/// Result of an [EmployeeProfileController.changePassword] attempt, so the
/// Change Password screen can show the right message without the
/// controller reaching into the UI itself.
enum ChangePasswordResult {
  success,
  incorrectCurrentPassword,
  newPasswordTooShort,
  newPasswordsDoNotMatch,
}

/// Owns the signed-in employee's profile — backs the "Profile Information",
/// "Edit Profile", and "Change Password" screens.
///
/// Frontend-only: there is no backend yet, so this simply holds one mock
/// employee in memory (seeded on first use) and keeps whatever edits are
/// made for the rest of the session.
class EmployeeProfileController extends ChangeNotifier {
  EmployeeProfileController._();

  static final EmployeeProfileController instance = EmployeeProfileController._();

  factory EmployeeProfileController() => instance;

  EmployeeProfile _profile = const EmployeeProfile(
    firstName: 'Juan',
    middleInitial: 'D',
    lastName: 'Dela Cruz',
    email: 'juan.delacruz@sarisari.com',
    contactNumber: '0917 123 4567',
    role: 'Employee',
  );

  // Mock-only credential store — never sent anywhere, just lets the
  // Change Password screen validate "Current Password" against something.
  String _password = 'password123';

  EmployeeProfile get profile => _profile;

  void updateProfile({
    String? firstName,
    String? middleInitial,
    String? lastName,
    String? email,
    String? contactNumber,
  }) {
    _profile = _profile.copyWith(
      firstName: firstName,
      middleInitial: middleInitial,
      lastName: lastName,
      email: email,
      contactNumber: contactNumber,
    );
    notifyListeners();
  }

  /// Sets or clears (pass `null`) the profile photo. Kept separate from
  /// [updateProfile] since `copyWith` can't tell "leave unchanged" apart
  /// from "clear this" for a nullable field.
  void setPhoto(String? photoPath) {
    _profile = EmployeeProfile(
      firstName: _profile.firstName,
      middleInitial: _profile.middleInitial,
      lastName: _profile.lastName,
      email: _profile.email,
      contactNumber: _profile.contactNumber,
      role: _profile.role,
      photoPath: photoPath,
    );
    notifyListeners();
  }

  ChangePasswordResult changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (currentPassword != _password) {
      return ChangePasswordResult.incorrectCurrentPassword;
    }
    if (newPassword.length < 8) {
      return ChangePasswordResult.newPasswordTooShort;
    }
    if (newPassword != confirmPassword) {
      return ChangePasswordResult.newPasswordsDoNotMatch;
    }
    _password = newPassword;
    notifyListeners();
    return ChangePasswordResult.success;
  }
}