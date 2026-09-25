// lib/authentication/forgot_password/otp_verification_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/utils/top_notification.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/user_profile_sync_service.dart';
import '../../core/services/emailjs_service.dart';
import '../../users/customer_db/customer_db.dart';
import '../../users/employee_db/employee_db.dart';
import '../../users/owner_db/owner_db.dart';
import 'create_new_password_page.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.email,
    this.expectedOtp,
    this.firstName,
    this.middleInitial,
    this.surname,
    this.phone,
    this.password,
    this.isSignUpFlow = true,
  });

  final String email;
  final String? expectedOtp;
  final String? firstName;
  final String? middleInitial;
  final String? surname;
  final String? phone;
  final String? password;
  final bool isSignUpFlow;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  static const int _otpLength = 6;
  final List<TextEditingController> _controllers = List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_otpLength, (_) => FocusNode());

  late String _currentOtp;
  Timer? _timer;
  int _remainingSeconds = 180; // 3 minutes maximum
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.expectedOtp ?? (100000 + Random().nextInt(900000)).toString();
    _sendEmailOtp();
    _startTimer();
  }

  Future<void> _sendEmailOtp() async {
    final success = await EmailJsService.instance.sendOtpEmail(
      recipientEmail: widget.email,
      otpCode: _currentOtp,
      recipientName: widget.firstName,
    );

    if (mounted) {
      if (success) {
        TopNotification.show(
          context,
          'Verification code sent to ${widget.email}. Please check your email inbox.',
        );
      } else {
        TopNotification.show(
          context,
          'Failed to send verification email. Please check your internet connection or email address.',
          isError: true,
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 180;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _nextField(String value, int index) {
    // Handle pasting multiple digits into box
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _otpLength && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= _otpLength) {
        _focusNodes[_otpLength - 1].unfocus();
      } else if (digits.isNotEmpty) {
        _focusNodes[min(digits.length, _otpLength - 1)].requestFocus();
      }
      _checkAndAutoSubmit();
      return;
    }

    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    _checkAndAutoSubmit();
  }

  void _checkAndAutoSubmit() {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == _otpLength && !_isVerifying) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    // 1. Check if OTP expired (3mins limit)
    if (_remainingSeconds <= 0) {
      TopNotification.show(
        context,
        'OTP code has expired. Please tap "Resend Code" to get a new code.',
        isError: true,
      );
      return;
    }

    // 2. Check if complete
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < _otpLength && otp.length < 4) {
      TopNotification.show(context, 'Please enter the complete verification code.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    bool isVerified = (otp == _currentOtp);

    if (!isVerified) {
      if (mounted) {
        setState(() => _isVerifying = false);
        TopNotification.show(context, 'Invalid verification code. Please check your email and try again.', isError: true);
      }
      return;
    }

    // Verification successful! Complete Sign-up & Auto-Login
    if (widget.isSignUpFlow) {
      final displayName = '${widget.firstName ?? ''} ${widget.middleInitial != null && widget.middleInitial!.isNotEmpty ? '${widget.middleInitial}. ' : ''}${widget.surname ?? ''}'
          .replaceAll('  ', ' ')
          .trim();

      final errorMessage = await AuthService().createAccountWithEmailPassword(
        email: widget.email.trim(),
        password: widget.password ?? '',
        displayName: displayName,
        firstName: widget.firstName?.trim(),
        middleInitial: widget.middleInitial?.trim(),
        surname: widget.surname?.trim(),
        phone: widget.phone?.trim(),
      );

      if (errorMessage != null) {
        if (mounted) {
          setState(() => _isVerifying = false);
          TopNotification.show(context, errorMessage, isError: true);
        }
        return;
      }

      // Sync user profile details across Firebase RTDB and Supabase
      final currentUser = AuthService().currentUser;
      if (currentUser != null) {
        String inferredRole = 'customer';
        final emailLower = widget.email.trim().toLowerCase();
        if (emailLower.contains('admin')) {
          inferredRole = 'admin';
        } else if (emailLower.contains('owner')) {
          inferredRole = 'owner';
        } else if (emailLower.contains('employee')) {
          inferredRole = 'employee';
        }

        try {
          await UserProfileSyncService().saveProfileInfo(
            uid: currentUser.uid,
            firstName: widget.firstName?.trim() ?? '',
            middleInitial: widget.middleInitial?.trim() ?? '',
            surname: widget.surname?.trim() ?? '',
            email: widget.email.trim(),
            phone: widget.phone?.trim() ?? '',
          );
          await SupabaseService().updateUserProfile(currentUser.uid, {
            'firstName': widget.firstName?.trim(),
            'middleInitial': widget.middleInitial?.trim(),
            'surname': widget.surname?.trim(),
            'email': widget.email.trim(),
            'phone': widget.phone?.trim(),
            'role': inferredRole,
          });
        } catch (e) {
          debugPrint('Error syncing profile: $e');
        }
      }

      // Check user role for Auto Login navigation
      final bool isOwner = await AuthService().hasRole('owner');
      final bool isEmployee = await AuthService().hasRole('employee');

      Widget destination;
      if (isOwner) {
        destination = const OwnerDb();
      } else if (isEmployee) {
        destination = const EmployeeDb();
      } else {
        destination = const CustomerDb();
      }

      if (mounted) {
        TopNotification.show(context, 'Account verified! Welcome to Tindahan ni Eca.');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => destination),
          (route) => false,
        );
      }
    } else {
      // Forgot Password flow
      if (mounted) {
        setState(() => _isVerifying = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CreateNewPasswordPage(),
          ),
        );
      }
    }
  }

  Future<void> _handleResendCode() async {
    if (_remainingSeconds > 0) return; // Bawal mag resend habang di pa expired ang 3 mins

    _currentOtp = (100000 + Random().nextInt(900000)).toString();

    setState(() {
      for (var controller in _controllers) {
        controller.clear();
      }
    });

    _startTimer();
    _focusNodes[0].requestFocus();

    await _sendEmailOtp();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTimerActive = _remainingSeconds > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'OTP Verification',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'We have sent a verification code to your email '),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: '. Please check your inbox.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Countdown Timer Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isTimerActive
                      ? AppColors.primaryOrange.withValues(alpha: 0.08)
                      : Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isTimerActive
                        ? AppColors.primaryOrange.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isTimerActive ? Icons.timer_outlined : Icons.error_outline,
                      color: isTimerActive ? AppColors.primaryOrange : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isTimerActive
                            ? 'Code expires in $_formattedTime'
                            : 'OTP code has expired! Please request a new code.',
                        style: TextStyle(
                          color: isTimerActive ? AppColors.primaryOrange : Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 6 OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_otpLength, (index) {
                  return SizedBox(
                    width: 44,
                    height: 52,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      onChanged: (value) => _nextField(value, index),
                      onSubmitted: (_) => _verifyOtp(),
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_otpLength),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.lightPeach,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primaryOrange,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),
              PrimaryButton(
                label: _isVerifying ? 'Verifying...' : 'Verify Code',
                isLoading: _isVerifying,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: 24),

              // Resend code section (bawal mag resend hanggat di pa natatapos ung 3mins)
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Didn't receive the code? ",
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: isTimerActive ? null : _handleResendCode,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isTimerActive ? 'Resend Code in $_formattedTime' : 'Resend Code',
                            style: TextStyle(
                              color: isTimerActive ? AppColors.secondaryText : AppColors.primaryOrange,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isTimerActive) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Resend button will be enabled after the timer expires.',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
