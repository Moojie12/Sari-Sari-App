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

    if (!mounted) return;

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

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = 180;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _nextField(String value, int index) {
    if (value.length == 1) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == _otpLength && !_isVerifying) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    if (_remainingSeconds <= 0) {
      TopNotification.show(
        context,
        'OTP code has expired. Please tap "Resend Code" to get a new code.',
        isError: true,
      );
      return;
    }

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
      if (mounted) {
        setState(() => _isVerifying = false);
        TopNotification.show(context, 'OTP verified! Set your new password.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CreateNewPasswordPage(email: widget.email),
          ),
        );
      }
    }
  }

  Future<void> _handleResendCode() async {
    if (_remainingSeconds > 0) return;

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
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_image.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.78),
                    Colors.black.withValues(alpha: 0.52),
                    AppColors.primaryOrange.withValues(alpha: 0.38),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final isDesktop = screenWidth >= 1024;
                    final isTablet = screenWidth >= 768 && screenWidth < 1024;

                    return Center(
                      child: isDesktop || isTablet
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  flex: isDesktop ? 5 : 6,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isDesktop ? 460 : 410,
                                    ),
                                    child: _buildOtpCard(isCompact: isTablet),
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 60 : 36),
                                Flexible(
                                  flex: isDesktop ? 6 : 5,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isDesktop ? 480 : 380,
                                    ),
                                    child: _buildBrandingSection(isCompact: isTablet),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildCompactBrandingSection(),
                                const SizedBox(height: 24),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 440),
                                  child: _buildOtpCard(isCompact: true),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard({bool isCompact = false}) {
    final bool isTimerActive = _remainingSeconds > 0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _verifyOtp,
      },
      child: Container(
        padding: EdgeInsets.all(isCompact ? 24 : 34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.verified_user_rounded,
                  size: 15,
                  color: AppColors.primaryOrange,
                ),
                SizedBox(width: 6),
                Text(
                  'OTP VERIFICATION',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            'Verification Code',
            style: TextStyle(
              fontSize: isCompact ? 22 : 26,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: isCompact ? 12 : 13,
                height: 1.35,
              ),
              children: [
                const TextSpan(text: 'Enter code sent to '),
                TextSpan(
                  text: widget.email,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 16 : 20),

          // Countdown Timer Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTimerActive
                        ? 'Expires in $_formattedTime'
                        : 'OTP code has expired! Please request a new code.',
                    style: TextStyle(
                      color: isTimerActive ? AppColors.primaryOrange : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 20 : 24),

          // OTP Boxes
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_otpLength, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
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
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: isCompact ? 20 : 28),

          PrimaryButton(
            label: _isVerifying ? 'Verifying...' : 'Verify Code',
            isLoading: _isVerifying,
            onPressed: _verifyOtp,
            height: isCompact ? 44 : 48,
          ),
          const SizedBox(height: 16),

          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Didn't receive code? ",
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
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
                        isTimerActive ? 'Resend in $_formattedTime' : 'Resend Code',
                        style: TextStyle(
                          color: isTimerActive ? AppColors.secondaryText : AppColors.primaryOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 15, color: AppColors.primaryOrange),
                  label: const Text(
                    'Back',
                    style: TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          const Center(
            child: Text(
              '© 2026 Tindahan ni Eca App System',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildBrandingSection({bool isCompact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCompact ? 80 : 96,
          height: isCompact ? 80 : 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 16 : 22),
        Text(
          'Tindahan ni Eca',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 32 : 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            shadows: const [
              Shadow(
                color: Colors.black87,
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.storefront_rounded, size: 16, color: AppColors.primaryOrange),
              SizedBox(width: 8),
              Text(
                'Management Portal & Retail Suite',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBrandingSection() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tindahan ni Eca',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black87,
                offset: Offset(0, 3),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Security Verification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}
