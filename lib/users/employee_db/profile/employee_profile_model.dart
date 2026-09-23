import 'package:flutter/foundation.dart';

/// Store-staff profile shown on the "Profile Information" screen and
/// edited from "Edit Profile" — name (with middle initial), email,
/// contact number, and role, per the Employee Profile spec. There is no
/// username field: Profile Information doesn't show one, so Edit Profile
/// doesn't have one to edit either.
@immutable
class EmployeeProfile {
  const EmployeeProfile({
    this.userId = '',
    required this.firstName,
    this.middleInitial = '',
    required this.lastName,
    required this.email,
    required this.contactNumber,
    required this.role,
    this.photoPath,
  });

  final String userId;
  final String firstName;

  /// e.g. "D" — shown as its own "Middle Initial" field.
  final String middleInitial;
  final String lastName;
  final String email;
  final String contactNumber;

  /// Local file path of the uploaded profile photo, or null when the
  /// employee hasn't added one yet (the avatar falls back to initials).
  final String? photoPath;

  /// e.g. "Cashier", "Inventory Staff" — shown read-only; role is assigned
  /// by the Owner, not editable from the Employee side.
  final String role;

  /// e.g. "Juan D. Dela Cruz" — middle initial (when set) is inserted
  /// between the first and last name.
  String get fullName {
    final mi = middleInitial.trim();
    if (mi.isEmpty) return '$firstName $lastName';
    final cleanMi = mi.endsWith('.') ? mi.substring(0, mi.length - 1) : mi;
    return '$firstName $cleanMi. $lastName';
  }

  /// Two-letter initials used by the avatar placeholder (e.g. "Juan Dela
  /// Cruz" -> "JD").
  String get initials {
    final firstInitial = firstName.isNotEmpty ? firstName[0] : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0] : '';
    final combined = '$firstInitial$lastInitial'.toUpperCase();
    return combined.isNotEmpty ? combined : '?';
  }

  EmployeeProfile copyWith({
    String? userId,
    String? firstName,
    String? middleInitial,
    String? lastName,
    String? email,
    String? contactNumber,
    String? role,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return EmployeeProfile(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      middleInitial: middleInitial ?? this.middleInitial,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      role: role ?? this.role,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }
}