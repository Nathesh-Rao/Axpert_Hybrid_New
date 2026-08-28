import 'package:axpert/app/modules/auth/controller/forgot_password_controller.dart';
import 'package:axpert/app/modules/auth/widget/login_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widget/login_field.dart';
// Make sure to import your custom widgets here:
// import 'package:axpert/app/modules/auth/widget/login_field.dart';
// import 'package:axpert/app/modules/auth/widget/login_button.dart';

class ForgetPasswordView extends GetView<ForgetPasswordController> {
  const ForgetPasswordView({super.key});

  // Safely extract the color from route arguments (works if passed directly or in a map)
  Color get _baseColor {
    if (Get.arguments != null) {
      if (Get.arguments is Map && Get.arguments['color'] != null) {
        return Get.arguments['color'];
      }
    }
    return const Color(0xff4B59D9);
  }

  String get _projectName {
    if (Get.arguments != null) {
      if (Get.arguments is Map && Get.arguments['project'] != null) {
        return Get.arguments['project'];
      }
    }
    return '';
  }

  String get _userName {
    if (Get.arguments != null) {
      if (Get.arguments is Color) return Get.arguments;
      if (Get.arguments is Map && Get.arguments['username'] != null) {
        return Get.arguments['username'];
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _baseColor;
    controller.userNameController.text = _userName;
    controller.projectName = _projectName;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 30, color: baseColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Forgot Password",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18.0,
            color: baseColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Container(
              // EXACT styling from your LoginView container
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Obx(
                () => controller.OTPSent.value
                    ? _buildOtpSection(context, baseColor)
                    : _buildEmailSection(context, baseColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // REQUEST OTP SECTION
  // ==========================================
  Widget _buildEmailSection(BuildContext context, Color baseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/axpert_full.png', // Or whatever logo you prefer here
          height: MediaQuery.of(context).size.height * 0.05,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        Text(
          'Reset Password',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: baseColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter email to receive an OTP',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),

        // Reusing your custom login field!
        WidgetLoginTextField(
          style2: true,
          label: "Username",
          hintText: "Enter User Name",
          prefixIcon: const Icon(Icons.person_outline),
          controller: controller.userNameController,
          errorText: controller.errUserName.value,
          baseColor: baseColor,
          readOnly: true, // Based on your original code
        ),

        WidgetLoginTextField(
          style2: true,
          label: "Email",
          hintText: "Enter Email Address",
          prefixIcon: const Icon(Icons.email_outlined),
          controller: controller.emailController,
          errorText: controller.emailError.value,
          baseColor: baseColor,
        ),

        const SizedBox(height: 40),

        // Reusing your custom button!
        WidgetLoginButton(
          label: 'PROCEED',
          color: baseColor,
          onPressed: () => controller.proceedButtonClicked(),
        ),
      ],
    );
  }

  // ==========================================
  // OTP & NEW PASSWORD SECTION
  // ==========================================
  Widget _buildOtpSection(BuildContext context, Color baseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "OTP sent successfully",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: baseColor,
          ),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enter OTP',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.black, // Matches WidgetLoginTextField label
                ),
              ),
              controller.showTimer.value
                  ? Text(
                      "Resend in ${controller.timerText.value}",
                      style: GoogleFonts.manrope(
                        color: baseColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : InkWell(
                      onTap: () => controller.reSendOTP(),
                      child: Text(
                        "Resend OTP",
                        style: GoogleFonts.manrope(
                          color: baseColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
            ],
          ),
        ),

        // OTP Field
        WidgetLoginTextField(
          style2: true,
          label: "", // Label handled in the row above
          hintText: "Enter OTP",
          prefixIcon: const Icon(Icons.pin_outlined),
          controller: controller.otpController,
          errorText: controller.otpError.value,
          baseColor: baseColor,
        ),

        // Passwords
        // Note: Because your WidgetLoginTextField inherently handles the obscure/visibility toggle
        // internally via `_isObscured`, you just need to pass `obscureText: true`!
        WidgetLoginTextField(
          style2: true,
          label: "New Password",
          hintText: "Enter New Password",
          prefixIcon: const Icon(Icons.lock_outline),
          controller: controller.passwordController,
          errorText: controller.passError.value,
          baseColor: baseColor,
          obscureText: true,
        ),

        WidgetLoginTextField(
          style2: true,
          label: "Confirm Password",
          hintText: "Confirm Password",
          prefixIcon: const Icon(Icons.lock_outline),
          controller: controller.confirmPasswordController,
          errorText: controller.conPassError.value,
          baseColor: baseColor,
          obscureText: true,
        ),

        const SizedBox(height: 40),

        WidgetLoginButton(
          label: 'SUBMIT',
          color: baseColor,
          onPressed: () => controller.submitOTPClicked(),
        ),
      ],
    );
  }
}
