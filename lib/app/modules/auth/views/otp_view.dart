import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/widgets/connection_style.dart';
import '../../../core/common.dart';
import '../controller/auth_controller.dart';
import '../widget/otp_field.dart';
import '../../../widgets/project_logo.dart';

class OTPView extends GetView<AuthController> {
  const OTPView({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) Get.offAllNamed(Routes.LOGIN);
    },
    child: Scaffold(
      backgroundColor: ConnectionStyle.card(context),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                ConnectionHero(
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          left: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: .14),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: IconButton(
                              tooltip: 'Back to sign in',
                              onPressed: () => Get.offAllNamed(Routes.LOGIN),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 58),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              children: [
                                Obx(
                                  () => ProjectLogo(
                                    url:
                                        controller
                                            .selectedProject
                                            .value
                                            ?.logourl ??
                                        '',
                                    projectName:
                                        controller.currentProjectName.value,
                                    size: 72,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Enter OTP',
                                  style: ConnectionStyle.text(
                                    context,
                                    26,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Obx(
                                  () => Text(
                                    controller.otpMsg.value,
                                    textAlign: TextAlign.center,
                                    style: ConnectionStyle.text(
                                      context,
                                      12.5,
                                      color: Colors.white.withValues(
                                        alpha: .82,
                                      ),
                                    ).copyWith(height: 1.55),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.storage_outlined,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Obx(
                                          () => Text(
                                            controller.currentProjectName.value,
                                            textAlign: TextAlign.center,
                                            style: ConnectionStyle.text(
                                              context,
                                              12.5,
                                              weight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -34),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    decoration: BoxDecoration(
                      color: ConnectionStyle.card(context),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () => WidgetOtpTextField(
                            label: 'One-time password',
                            controller: controller.otpFieldController,
                            isLoading: controller.isOtpLoading.value,
                            otpLength: int.parse(controller.otpChars.value),
                            errorText: controller.otpErrorText.value,
                            onCompleted: () => controller.callVerifyOTP(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: ConnectionStyle.tint(context),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    size: 14,
                                    color: ConnectionStyle.ink(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Obx(
                                    () => Text(
                                      controller.otpFormattedTime,
                                      style: ConnectionStyle.text(
                                        context,
                                        12.5,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Obx(
                              () => TextButton(
                                onPressed: controller.isOtpTimerActive
                                    ? null
                                    : () => controller.callResendOTP(),
                                child: Text(
                                  controller.isOtpTimerActive
                                      ? 'Resend in ${controller.otpRemainingSeconds.value}s'
                                      : 'Resend code',
                                  style:
                                      ConnectionStyle.text(
                                        context,
                                        12.5,
                                        weight: FontWeight.w700,
                                        color: controller.isOtpTimerActive
                                            ? ConnectionStyle.muted(context)
                                            : ConnectionStyle.ink(context),
                                      ).copyWith(
                                        decoration: controller.isOtpTimerActive
                                            ? TextDecoration.none
                                            : TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ConnectionButton(
                            label: 'Login',
                            onPressed: () => controller.callVerifyOTP(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text:
                                      'By using the software, you agree to the\n',
                                ),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: ConnectionStyle.dark(context)
                                        ? const Color(0xff9DB6FF)
                                        : ConnectionStyle.navy,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: ' and the '),
                                TextSpan(
                                  text: 'Terms of Use',
                                  style: TextStyle(
                                    color: ConnectionStyle.dark(context)
                                        ? const Color(0xff9DB6FF)
                                        : ConnectionStyle.navy,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: ConnectionStyle.text(
                              context,
                              11.5,
                              color: ConnectionStyle.muted(context),
                            ).copyWith(height: 1.6),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Center(
                          child: Text(
                            'Powered by Axpert',
                            style: ConnectionStyle.text(
                              context,
                              11,
                              color: ConnectionStyle.muted(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: FutureBuilder<String>(
                            future: controller.getVersionName(),
                            builder: (context, snapshot) => snapshot.hasData
                                ? Text(
                                    'v${snapshot.data}_${AppConst.APP_RELEASE_ID}_${AppConst.APP_RELEASE_DATE}',
                                    textAlign: TextAlign.center,
                                    style: ConnectionStyle.text(
                                      context,
                                      10,
                                      color: ConnectionStyle.muted(context),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.paddingOf(context).bottom + 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
