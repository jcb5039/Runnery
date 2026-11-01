import 'package:flutter/material.dart';

import '../../design_system/app_colors.dart';
import '../../design_system/app_text_styles.dart';

TextStyle get authLabelStyle => TextStyle(
  fontFamily: 'Archivo',
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.54,
  color: AppColors.textSecondary,
  fontVariations: [FontVariation('wdth', 125)],
);

class RegistrationData {
  const RegistrationData({
    required this.name,
    required this.email,
    required this.id,
    required this.password,
    required this.age,
    required this.gender,
    required this.weight,
  });
  final String name, email, id, password, gender;
  final int age;
  final double weight;
}

/// A scrollable page with a bottom action; small screens and keyboards can scroll.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.content, required this.actions});
  final Widget content, actions;
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      brightness: Brightness.dark,
      fontFamily: AppTextStyles.bodyFontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        primary: AppColors.textPrimary,
        surface: AppColors.background,
        error: AppColors.error,
      ),
    ),
    child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (layoutContext, box) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    (64 - MediaQuery.paddingOf(context).top)
                        .clamp(8, 64)
                        .toDouble(),
                    24,
                    (50 - MediaQuery.paddingOf(context).bottom)
                        .clamp(16, 50)
                        .toDouble(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      const SizedBox(height: 32),
                      const Spacer(),
                      actions,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SignupHeading extends StatelessWidget {
  const SignupHeading({
    super.key,
    required this.step,
    required this.title,
    required this.description,
  });
  final int step;
  final String title, description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
              tooltip: '뒤로',
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '0$step',
                  style: TextStyle(
                    fontFamily: 'Archivo',
                    fontVariations: [FontVariation('wdth', 75)],
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' / 03',
                  style: authLabelStyle.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 11),
      Row(
        children: List.generate(
          3,
          (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
              child: Container(
                height: 2,
                color: i < step ? AppColors.textPrimary : AppColors.divider,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 32),
      Text('STEP 0$step', style: authLabelStyle),
      const SizedBox(height: 12),
      Text(
        title,
        style: TextStyle(
          fontFamily: 'Archivo',
          fontVariations: [FontVariation('wdth', 125)],
          fontSize: 28,
          height: 1.04,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        description,
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    ],
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.arrow = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool outlined, arrow;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: TextButton(
      style: TextButton.styleFrom(
        backgroundColor: outlined ? Colors.transparent : AppColors.textPrimary,
        foregroundColor: outlined
            ? AppColors.textPrimary
            : AppColors.background,
        shape: const StadiumBorder(),
        side: outlined
            ? BorderSide(color: AppColors.textPrimary)
            : BorderSide.none,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (arrow) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ],
      ),
    ),
  );
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.password = false,
    this.keyboard,
    this.validator,
    this.success,
    this.suffix,
    this.action = TextInputAction.next,
  });
  final String label;
  final TextEditingController controller;
  final String? hint, success, suffix;
  final bool password;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final TextInputAction action;
  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: authLabelStyle),
      const SizedBox(height: 8),
      TextFormField(
        controller: widget.controller,
        obscureText: widget.password && hidden,
        enableSuggestions: !widget.password,
        autocorrect: !widget.password,
        keyboardType: widget.keyboard,
        textInputAction: widget.action,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: widget.validator,
        onChanged: (_) => setState(() {}),
        cursorColor: AppColors.textPrimary,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          suffixText: widget.suffix,
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: hidden ? '비밀번호 보기' : '비밀번호 숨기기',
                  onPressed: () => setState(() => hidden = !hidden),
                  icon: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.borderDefault),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.textPrimary, width: 2),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
        ),
      ),
      if (widget.success != null &&
          widget.controller.text.isNotEmpty &&
          widget.validator?.call(widget.controller.text) == null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.check, size: 12, color: AppColors.textPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.success!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
