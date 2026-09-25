// lib/core/services/emailjs_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for sending emails directly to users using EmailJS REST API
class EmailJsService {
  EmailJsService._internal();
  static final EmailJsService instance = EmailJsService._internal();

  // Configure your EmailJS credentials here
  String serviceId = 'service_y6clpaf'; // Replace with your EmailJS Service ID
  String templateId = 'template_88xb4l7';     // Replace with your EmailJS Template ID
  String publicKey = 'WMyCWijMoWsabMttL';    // Replace with your EmailJS Public Key

  /// Configure EmailJS credentials programmatically
  void configure({
    required String serviceId,
    required String templateId,
    required String publicKey,
  }) {
    this.serviceId = serviceId;
    this.templateId = templateId;
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
}
