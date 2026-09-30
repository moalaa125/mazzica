import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mazzica/constants/app_color.dart';

class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.onSuffixTap,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: 0.04),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: CupertinoTextField(
        
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        autofocus: autofocus,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
        ),
        placeholderStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          fontSize: 15.sp,
          fontWeight: FontWeight.w400,
        ),
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
        decoration: const BoxDecoration(color: CupertinoColors.transparent),
        cursorColor: AppColors.lime,
        prefix: prefixIcon != null
            ? Padding(
                padding: EdgeInsets.only(left: 14.w),
                child: Icon(
                  prefixIcon,
                  color: AppColors.lime.withValues(alpha: 0.7),
                  size: 20.sp,
                ),
              )
            : null,
        suffix: suffixIcon != null
            ? Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(
                    suffixIcon,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    size: 20.sp,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
