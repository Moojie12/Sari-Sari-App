import 'package:flutter/foundation.dart';

/// Customer profile shown on the "Profile Information" screen and edited
/// from "Edit Profile" — name (with middle initial), email, and contact
/// number. Mirrors [EmployeeProfile] but has no username or role field:
/// a customer's role is always "Customer" and there is no separate
/// username, only account credentials used at login.
@immutable
class CustomerProfile {
  const CustomerProfile({
    required this.firstName,
    this.middleInitial = '',
    required this.lastName,
    required this.email,
    required this.contactNumber,
    this.photoPath,
  });

  final String firstName;

  /// e.g. "D" — shown as its own "Middle Initial" field.
  final String middleInitial;
  final String lastName;
  final String email;
  final String contactNumber;

  /// Local file path of the uploaded profile photo, or null when the
  /// customer hasn't added one yet (the avatar falls back to initials).
  final String? photoPath;

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

  CustomerProfile copyWith({
    String? firstName,
    String? middleInitial,
    String? lastName,
    String? email,
    String? contactNumber,
  }) {
    return CustomerProfile(
      firstName: firstName ?? this.firstName,
      middleInitial: middleInitial ?? this.middleInitial,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      photoPath: photoPath,
    );
  }
}