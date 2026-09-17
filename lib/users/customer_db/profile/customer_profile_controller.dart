import 'package:flutter/foundation.dart';

import 'customer_profile_model.dart';

/// Owns the signed-in customer's profile — backs the "Profile", "Profile
/// Information", and "Edit Profile" screens so all three always show the
/// same data.
///
/// Frontend-only: there is no backend yet, so this simply holds one mock
/// customer in memory (seeded on first use) and keeps whatever edits are
/// made for the rest of the session.
class CustomerProfileController extends ChangeNotifier {
  CustomerProfileController._();

  static final CustomerProfileController instance = CustomerProfileController._();

  factory CustomerProfileController() => instance;

  CustomerProfile _profile = const CustomerProfile(
    firstName: 'Juan',
    middleInitial: 'D',
    lastName: 'Dela Cruz',
    email: 'juan.delacruz@email.com',
    contactNumber: '+63 912 345 6789',
  );

  CustomerProfile get profile => _profile;

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
    _profile = CustomerProfile(
      firstName: _profile.firstName,
      middleInitial: _profile.middleInitial,
      lastName: _profile.lastName,
      email: _profile.email,
      contactNumber: _profile.contactNumber,
      photoPath: photoPath,
    );
    notifyListeners();
  }
}