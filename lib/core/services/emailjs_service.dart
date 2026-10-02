// lib/core/services/emailjs_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for sending emails directly to users using EmailJS REST API
class EmailJsService {
  EmailJsService._internal() {
    loadSavedCredentials();
  }
  static final EmailJsService instance = EmailJsService._internal();

  // Configure your EmailJS credentials here
  String serviceId = 'service_y6clpaf'; // Replace with your EmailJS Service ID
  String templateId = 'template_88xb4l7';     // Replace with your EmailJS OTP Template ID
  String credentialsTemplateId = 'template_3a3711q'; // Replace with your EmailJS Credentials Template ID
  String publicKey = 'WMyCWijMoWsabMttL';    // Replace with your EmailJS Public Key

  /// Loads saved EmailJS settings from local storage
  Future<void> loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      serviceId = prefs.getString('emailjs_service_id') ?? serviceId;
      templateId = prefs.getString('emailjs_template_id') ?? templateId;
      credentialsTemplateId = prefs.getString('emailjs_credentials_template_id') ?? credentialsTemplateId;
      publicKey = prefs.getString('emailjs_public_key') ?? publicKey;
    } catch (e) {
      debugPrint('Failed to load EmailJS prefs: $e');
    }
  }

  /// Saves updated EmailJS settings to local storage
  Future<void> saveCredentials({
    String? newServiceId,
    String? newTemplateId,
    String? newCredentialsTemplateId,
    String? newPublicKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newServiceId != null && newServiceId.isNotEmpty) {
        serviceId = newServiceId.trim();
        await prefs.setString('emailjs_service_id', serviceId);
      }
      if (newTemplateId != null && newTemplateId.isNotEmpty) {
        templateId = newTemplateId.trim();
        await prefs.setString('emailjs_template_id', templateId);
      }
      if (newCredentialsTemplateId != null && newCredentialsTemplateId.isNotEmpty) {
        credentialsTemplateId = newCredentialsTemplateId.trim();
        await prefs.setString('emailjs_credentials_template_id', credentialsTemplateId);
      }
      if (newPublicKey != null && newPublicKey.isNotEmpty) {
        publicKey = newPublicKey.trim();
        await prefs.setString('emailjs_public_key', publicKey);
      }
    } catch (e) {
      debugPrint('Failed to save EmailJS prefs: $e');
    }
  }

  /// Configure EmailJS credentials programmatically
  void configure({
    required String serviceId,
    required String templateId,
    String? credentialsTemplateId,
    required String publicKey,
  }) {
    this.serviceId = serviceId;
    this.templateId = templateId;
    this.credentialsTemplateId = credentialsTemplateId ?? templateId;
    this.publicKey = publicKey;
  }

  /// Sends an OTP verification email to [recipientEmail] via EmailJS API.
  /// Returns `true` if email was sent successfully.
  Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String otpCode,
    String? recipientName,
  }) async {
    const url = 'https://api.emailjs.com/api/v1.0/email/send';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': recipientEmail.trim(),
            'email': recipientEmail.trim(),
            'user_email': recipientEmail.trim(),
            'recipient_email': recipientEmail.trim(),
            'reply_to': recipientEmail.trim(),
            'to_name': recipientName?.trim() ?? 'User',
            'user_name': recipientName?.trim() ?? 'User',
            'name': recipientName?.trim() ?? 'User',
            'otp_code': otpCode,
            'otp': otpCode,
            'code': otpCode,
            'passcode': otpCode,
            'verification_code': otpCode,
            'message': 'Your verification code is: $otpCode',
            'app_name': 'Tindahan ni Eca',
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('EmailJS: Email successfully sent to $recipientEmail');
        return true;
      } else {
        debugPrint('EmailJS Error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('EmailJS Request Failed: $e');
      return false;
    }
  }

  /// Sends account credentials (temporary password) to [recipientEmail] via EmailJS API.
  Future<bool> sendAccountCredentialsEmail({
    required String recipientEmail,
    required String temporaryPassword,
    required String recipientName,
    required String roleName,
    String? customTemplateId,
  }) async {
    const url = 'https://api.emailjs.com/api/v1.0/email/send';
    final targetTemplateId = customTemplateId ?? credentialsTemplateId;

    debugPrint('EmailJS: Sending credentials to $recipientEmail using template_id: $targetTemplateId (service: $serviceId)');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': targetTemplateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': recipientEmail.trim(),
            'email': recipientEmail.trim(),
            'user_email': recipientEmail.trim(),
            'recipient_email': recipientEmail.trim(),
            'reply_to': recipientEmail.trim(),
            'to_name': recipientName.trim(),
            'user_name': recipientName.trim(),
            'name': recipientName.trim(),
            'otp_code': temporaryPassword,
            'otp': temporaryPassword,
            'code': temporaryPassword,
            'passcode': temporaryPassword,
            'verification_code': temporaryPassword,
            'password': temporaryPassword,
            'temporary_password': temporaryPassword,
            'temp_password': temporaryPassword,
            'role': roleName,
            'user_role': roleName,
            'message': 'Hello $recipientName,\n\nYour account has been created successfully as a $roleName on Tindahan ni Eca.\n\nYour temporary password is: $temporaryPassword\n\nYou can use this password to log in. You may change it anytime in your profile or via forgot password.',
            'app_name': 'Tindahan ni Eca',
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('EmailJS: Credentials email successfully sent to $recipientEmail');
        return true;
      } else {
        debugPrint('EmailJS Error (${response.statusCode}): ${response.body}');

        // Fallback retry if custom template ID was not found in EmailJS
        if (targetTemplateId != templateId) {
          debugPrint('EmailJS: Retrying with fallback default templateId ($templateId)...');
          return await sendAccountCredentialsEmail(
            recipientEmail: recipientEmail,
            temporaryPassword: temporaryPassword,
            recipientName: recipientName,
            roleName: roleName,
            customTemplateId: templateId,
          );
        }

        return false;
      }
    } catch (e) {
      debugPrint('EmailJS Request Failed: $e');
      return false;
    }
  }
}
