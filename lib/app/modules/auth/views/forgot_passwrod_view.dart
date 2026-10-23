import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../widgets/connection_style.dart';
import '../../../widgets/project_logo.dart';
import '../controller/auth_controller.dart';
import '../controller/forgot_password_controller.dart';

class ForgetPasswordView extends StatefulWidget {
  const ForgetPasswordView({super.key});
  @override
  State<ForgetPasswordView> createState() => _ForgetPasswordViewState();
}

class _ForgetPasswordViewState extends State<ForgetPasswordView> {
  final ForgetPasswordController controller = Get.find();
  late final Future<PackageInfo> _version;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      controller.userNameController.text = args['username']?.toString() ?? '';
      controller.projectName = args['project']?.toString() ?? '';
    }
    _version = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ConnectionStyle.card(context),
    body: CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: ConnectionHero(
            child: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 58),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: .14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: IconButton(
                                tooltip: 'Back to sign in',
                                onPressed: () => Get.back(),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Forgot password',
                                textAlign: TextAlign.center,
                                style: ConnectionStyle.text(
                                  context,
                                  17,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (Get.isRegistered<AuthController>())
                          Obx(() {
                            final auth = Get.find<AuthController>();
                            return ProjectLogo(
                              url: auth.selectedProject.value?.logourl ?? '',
                              projectName: auth.currentProjectName.value,
                              size: 68,
                            );
                          })
                        else
                          const ProjectLogo(url: '', size: 68),
                        const SizedBox(height: 16),
                        Obx(
                          () => Text(
                            controller.OTPSent.value
                                ? 'Enter your OTP and choose a new password'
                                : 'Enter your email to recover your password',
                            textAlign: TextAlign.center,
                            style: ConnectionStyle.text(
                              context,
                              14,
                              color: Colors.white.withValues(alpha: .82),
                            ).copyWith(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: ConnectionStyle.card(context),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(
                    () => controller.OTPSent.value
                        ? _otpForm(context)
                        : _emailForm(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: FutureBuilder<PackageInfo>(
                      future: _version,
                      builder: (context, snapshot) => Text(
                        snapshot.hasData
                            ? 'v${snapshot.data!.version} · Axpert'
                            : 'Axpert',
                        style: ConnectionStyle.text(
                          context,
                          11,
                          color: ConnectionStyle.muted(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _emailForm(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _field(
        context,
        label: 'Username',
        hint: 'Enter your username',
        icon: Icons.person_outline,
        textController: controller.userNameController,
        error: controller.errUserName.value,
        readOnly: true,
      ),
      const SizedBox(height: 20),
      _field(
        context,
        label: 'Email address',
        hint: 'Enter email address',
        icon: Icons.email_outlined,
        textController: controller.emailController,
        error: controller.emailError.value,
        keyboard: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: ConnectionStyle.tint(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 18,
              color: ConnectionStyle.dark(context)
                  ? const Color(0xff9DB6FF)
                  : ConnectionStyle.navy,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Use the email address linked to your account. Password recovery instructions will be sent to this address.',
                style: ConnectionStyle.text(context, 12).copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      ConnectionButton(
        label: controller.isFPasswordLoading.value
            ? 'Please wait...'
            : 'Proceed',
        icon: Icons.arrow_forward,
        loading: controller.isFPasswordLoading.value,
        onPressed: controller.proceedButtonClicked,
      ),
    ],
  );

  Widget _otpForm(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'OTP sent successfully',
        style: ConnectionStyle.text(context, 18, weight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            'Check your email for the code.',
            style: ConnectionStyle.text(
              context,
              12,
              color: ConnectionStyle.muted(context),
            ),
          ),
          TextButton(
            onPressed: controller.showTimer.value ? null : controller.reSendOTP,
            child: Text(
              controller.showTimer.value
                  ? 'Resend in ${controller.timerText.value}'
                  : 'Resend OTP',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _field(
        context,
        label: 'One-time password',
        hint: 'Enter OTP',
        icon: Icons.pin_outlined,
        textController: controller.otpController,
        error: controller.otpError.value,
      ),
      const SizedBox(height: 20),
      _field(
        context,
        label: 'New password',
        hint: 'Enter new password',
        icon: Icons.lock_outline,
        textController: controller.passwordController,
        error: controller.passError.value,
        obscure: _hidePassword,
        suffix: IconButton(
          tooltip: _hidePassword ? 'Show new password' : 'Hide new password',
          onPressed: () => setState(() => _hidePassword = !_hidePassword),
          icon: Icon(
            _hidePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      const SizedBox(height: 20),
      _field(
        context,
        label: 'Confirm password',
        hint: 'Confirm new password',
        icon: Icons.lock_outline,
        textController: controller.confirmPasswordController,
        error: controller.conPassError.value,
        obscure: _hideConfirmation,
        suffix: IconButton(
          tooltip: _hideConfirmation
              ? 'Show confirmation password'
              : 'Hide confirmation password',
          onPressed: () =>
              setState(() => _hideConfirmation = !_hideConfirmation),
          icon: Icon(
            _hideConfirmation
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      const SizedBox(height: 24),
      ConnectionButton(
        label: controller.isFPasswordLoading.value
            ? 'Please wait...'
            : 'Submit',
        loading: controller.isFPasswordLoading.value,
        onPressed: controller.submitOTPClicked,
      ),
    ],
  );

  Widget _field(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController textController,
    required String error,
    bool readOnly = false,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    Iterable<String>? autofillHints,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          label,
          style: ConnectionStyle.text(
            context,
            12,
            weight: FontWeight.w600,
            color: ConnectionStyle.muted(context),
          ),
        ),
      ),
      TextField(
        controller: textController,
        readOnly: readOnly,
        obscureText: obscure,
        keyboardType: keyboard,
        autofillHints: autofillHints,
        autocorrect: false,
        style: ConnectionStyle.text(context, 15),
        decoration: ConnectionStyle.input(
          context,
          hint,
          icon,
          error: error,
          suffix: suffix,
        ).copyWith(errorMaxLines: 3),
      ),
    ],
  );
}
