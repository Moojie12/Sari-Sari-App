import 'package:flutter/foundation.dart';

/// Store-staff profile shown on the "Profile Information" screen and
/// edited from "Edit Profile" — name, username, email, contact number,
/// and role, per the Employee Profile spec.
@immutable
class EmployeeProfile {
  const EmployeeProfile({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.contactNumber,
    required this.role,
  });

  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String contactNumber;

  /// e.g. "Cashier", "Inventory Staff" — shown read-only; role is assigned
  /// by the Owner, not editable from the Employee side.
  final String role;

  String get fullName => '$firstName $lastName';

  /// Two-letter initials used by the avatar placeholder (e.g. "Juan Dela
  /// Cruz" -> "JD").
  String get initials {
    final firstInitial = firstName.isNotEmpty ? firstName[0] : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0] : '';
    final combined = '$firstInitial$lastInitial'.toUpperCase();
    return combined.isNotEmpty ? combined : '?';
  }

  EmployeeProfile copyWith({
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? contactNumber,
    String? role,
  }) {
    return EmployeeProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      role: role ?? this.role,
    );
  }
}