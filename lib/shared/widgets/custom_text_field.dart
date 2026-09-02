import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A styled text field used across the app's forms.
/// Set [isPassword] to true to get an obscure/reveal toggle for free —
/// the widget manages that state internally so screens don't have to.
///
/// Lives in `shared/` because both the login and sign up features use it.
/// If a future feature needs a field only it will ever use, put that one
/// inside that feature's own `widgets/` folder instead.
class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.trailing,
  });

  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;
  final TextInputType keyboardType;

  /// Optional extra widget shown after the field (e.g. a scan-ID button).
  /// Ignored when [isPassword] is true, since that slot is used for the
  /// visibility toggle instead.
  final Widget? trailing;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(
          color: AppColors.placeholderColor,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          widget.icon,
          size: 18,
          color: AppColors.primaryOrange,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: AppColors.placeholderColor,
          ),
        )
            : widget.trailing,
        filled: true,
        fillColor: AppColors.lightPeach,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primaryOrange,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}