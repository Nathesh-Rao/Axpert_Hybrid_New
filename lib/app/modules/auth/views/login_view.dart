import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/data/const/app_const.dart';
import 'package:axpert/app/modules/auth/controller/auth_controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:axpert/app/modules/auth/widget/login_button.dart';
import 'package:axpert/app/modules/auth/widget/login_field.dart';
import 'package:axpert/app/widgets/widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../data/enums/auth_enums.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.onLoad();
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        await controller.showExitConfirmationSheet();
      },
      child: AppScaffold(
        // bgIMage: "assets/images/login_bg2.png",
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Obx(
            () => Skeletonizer(
              enabled: controller.selectedProject.value == null,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        30.verticalSpace,
                        Container(
                          clipBehavior: Clip.hardEdge,
                          padding: const EdgeInsets.all(10),
                          width: MediaQuery.of(context).size.width * 0.25,
                          height: MediaQuery.of(context).size.width * 0.25,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            // shape: BoxShape.circle,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xff4B59D9).withValues(alpha: 0.5),
                                blurRadius: 12,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Image.network(
                            controller.selectedProject.value?.logourl ?? '',
                            width: MediaQuery.of(context).size.width * 0.24,
                            fit: BoxFit.contain,
                            // frameBuilder:
                            //     (context, child, frame, wasSynchronouslyLoaded) {
                            //       if (wasSynchronouslyLoaded || frame != null) {
                            //         return child;
                            //       }
                            //       return SizedBox(
                            //         width: MediaQuery.of(context).size.width * 0.24,
                            //         child: const Center(child: LoadingLottieWidget()),
                            //       );
                            //     },
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/axpert_logo_new.png',
                                width: MediaQuery.of(context).size.width * 0.24,
                                fit: BoxFit.fill,
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.01,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 10,
                          children: [
                            Text(
                              "Welcome",
                              style: GoogleFonts.poppins(
                                fontSize: 34,
                                fontWeight: FontWeight.w600,
                                color: AppColors.AXMDark,
                              ),
                            ),
                            Obx(
                              () => Text(
                                "Back!",
                                style: GoogleFonts.poppins(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      controller.selectedColor.value ??
                                      Color(0xff4B59D9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Sign in to enjoy the best\nmanaging experience",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.AXMGray,
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.025,
                        ),
                        Obx(
                          () => _projectNameWidget(
                            projectName: controller.currentProjectName.value
                                .toUpperCase(),
                            color: controller.selectedColor.value,
                            onAddButtonPressed: () {
                              Get.offNamed(Routes.PROJECT_CONFIG);
                            },
                            onProjectSelected: controller.projectChanged,
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.015,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xff4B59D9).withOpacity(0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            // shadowColor: Color(0xff4B59D9),
                            // elevation: 5,
                            // shape: RoundedRectangleBorder(
                            //   borderRadius: BorderRadius.circular(30),
                            // ),
                            child: Column(
                              children: [
                                Obx(
                                  () => WidgetLoginTextField(
                                    style2: true,
                                    key: const ValueKey("username"),
                                    hintText: "Enter Username",
                                    label: "Username",
                                    prefixIcon: const Icon(Icons.person),
                                    isLoading:
                                        controller.isUserDataLoading.value,
                                    controller: controller.userNameController,
                                    errorText: controller.errUserName.value,
                                    baseColor: controller.selectedColor.value,
                                  ),
                                ),
                                Obx(
                                  () => AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    transitionBuilder: (child, animation) {
                                      final fade = FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                      return SizeTransition(
                                        sizeFactor: animation,
                                        axis: Axis.vertical,
                                        child: fade,
                                      );
                                    },
                                    child: controller.isPWD_auth.value
                                        ? WidgetLoginTextField(
                                            prefixIcon: Icon(Icons.lock),
                                            key: const ValueKey("rotating"),
                                            label: "Password",
                                            hintText: "Enter Password",
                                            focusNode: controller.passwordFocus,
                                            obscureText:
                                                controller.showPassword.value,
                                            errorText:
                                                controller.errPassword.value,
                                            controller: controller
                                                .userPasswordController,
                                            baseColor:
                                                controller.selectedColor.value,
                                          )
                                        : const SizedBox.shrink(
                                            key: ValueKey("empty"),
                                          ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Obx(
                                  () => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            controller.rememberMe.toggle();
                                          },
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value:
                                                    controller.rememberMe.value,
                                                onChanged: (value) => {
                                                  controller.rememberMe
                                                      .toggle(),
                                                },
                                                checkColor: Colors.white,
                                                side: BorderSide(
                                                  color:
                                                      controller
                                                          .selectedColor
                                                          .value ??
                                                      AppColors.darkBlue,
                                                  width: 2,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                activeColor:
                                                    controller
                                                        .selectedColor
                                                        .value ??
                                                    AppColors.darkBlue,
                                              ),
                                              Text(
                                                "Remember Me",
                                                style: GoogleFonts.manrope(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // InkWell(
                                        //   onTap: () {
                                        //     Get.toNamed(Routes.ForgetPassword);
                                        //   },
                                        //   child: Text("Forgot Password?",
                                        //       style: GoogleFonts.manrope(
                                        //         decoration:
                                        //             TextDecoration.underline,
                                        //         fontWeight: FontWeight.w600,
                                        //         fontSize: 13,
                                        //         color: Colors.blueAccent,
                                        //       )),
                                        // )
                                        Obx(
                                          () => controller.isPWD_auth.value
                                              ? InkWell(
                                                  onTap: () {
                                                    // Get.toNamed(
                                                    //   Routes.ForgetPassword,
                                                    // );
                                                  },
                                                  child: Text(
                                                    "Forgot Password?",
                                                    style: GoogleFonts.manrope(
                                                      decoration: TextDecoration
                                                          .underline,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Colors.blueAccent,
                                                    ),
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height *
                                      0.025,
                                ),
                                Obx(
                                  () => WidgetLoginButton(
                                    icon: Icon(Icons.security),
                                    label: "NEXT",
                                    visible:
                                        controller.authType.value ==
                                            AuthType.none ||
                                        controller.authType.value ==
                                            AuthType.otpOnly,
                                    onPressed: () {
                                      controller.startLoginProcess();
                                    },
                                    color: controller.selectedColor.value,
                                  ),
                                ),
                                Obx(
                                  () => Skeletonizer(
                                    enabled:
                                        controller.isSigninApiCalling.value,
                                    child: WidgetLoginButton(
                                      icon: Icon(Icons.security),
                                      label: _getLoginButtonLabel(),
                                      visible:
                                          controller.authType.value ==
                                              AuthType.both ||
                                          controller.authType.value ==
                                              AuthType.passwordOnly,
                                      onPressed: () {
                                        controller.callSignInAPI();
                                      },
                                      color: controller.selectedColor.value,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height *
                                      0.025,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Center(
                        //   child: Text("${MediaQuery.of(context).size.height * 0.065}"),
                        // ),
                        SizedBox(height: 20),
                        Visibility(
                          visible: controller.googleSignInVisible.value,
                          child: Padding(
                            padding: EdgeInsets.only(left: 30, right: 30),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                foregroundColor: AppColors.moreDark,
                                backgroundColor: AppColors.white,
                                minimumSize: Size(double.infinity, 60),
                              ),
                              icon: FaIcon(
                                FontAwesomeIcons.google,
                                color: AppColors.accentRed,
                              ),
                              label: Text(
                                'Sign In With Google',
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                    color: Color(0xff3E4153),
                                  ),
                                ),
                              ),
                              onPressed: () {
                                // controller.googleSignInClicked();
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 10),

                        SizedBox(height: 20),
                        FittedBox(
                          child: Text(
                            "By using the software, you agree to the",
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                                letterSpacing: 1,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              child: Text(
                                "Privacy Policy",
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                    color: Colors.blue,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            FittedBox(
                              child: Text(
                                " and the",
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                    color: Colors.black,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            FittedBox(
                              child: Text(
                                " Terms of Use",
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                    color: Colors.blue,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),

                        // Text(
                        //   "Powered By",
                        //   textAlign: TextAlign.center,
                        //   style: GoogleFonts.poppins(
                        //     textStyle: TextStyle(
                        //       fontWeight: FontWeight.w500,
                        //       fontSize: 12,
                        //       color: Colors.black,
                        //       letterSpacing: 1,
                        //     ),
                        //   ),
                        // ),
                        // Image.asset(
                        //   'assets/images/axpert_03.png',
                        //   height: MediaQuery.of(context).size.height * 0.04,
                        //   // width: MediaQuery.of(context).size.width * 0.075,
                        //   fit: BoxFit.fill,
                        // ),
                        AxpertInfoWidget(),

                        Visibility(
                          visible:
                              controller.isBiometricAvailable.value &&
                              controller.willBio_userAuthenticate.value,
                          child: GestureDetector(
                            onTap: () {
                              // controller.displayAuthenticationDialog();
                            },
                            child: Container(
                              color: Colors.transparent,
                              padding: EdgeInsets.all(20),
                              child: Icon(
                                Icons.fingerprint_outlined,
                                color: AppColors.darkBlue,
                                size: MediaQuery.of(context).size.height * 0.04,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 25, 10),
                      child: FutureBuilder(
                        future: controller.getVersionName(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(
                              "v${snapshot.data}_${AppConst.APP_RELEASE_DATE}",
                              // "v${snapshot.data}",
                              style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                  color: AppColors.moreDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize:
                                      MediaQuery.of(context).size.height *
                                      0.012,
                                ),
                              ),
                            );
                          } else {
                            return Text("");
                          }
                        },
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

  // Widget _projectNameWidget({required String projectName, Color? color}) {
  //   var baseColor = color ?? Color(0xff4B59D9);

  //   return Row(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Container(
  //         padding: EdgeInsets.symmetric(vertical: 7, horizontal: 20),
  //         decoration: BoxDecoration(
  //           // color: Color(0xffD9D9D9).withAlpha(125),
  //           color: baseColor.withValues(alpha: 0.1),
  //           // boxShadow: [
  //           //   BoxShadow(
  //           //     color: Color(0xff4B59D9).withAlpha(50),
  //           //     blurRadius: 5,
  //           //   )
  //           // ],
  //           // border: Border.all(color: Color(0xff4B59D9).withAlpha(20)),
  //           // gradient: LinearGradient(
  //           //   colors: [
  //           //     Color(0xff4B59D9).withAlpha(20),
  //           //     Colors.white,
  //           //     Colors.white,
  //           //   ],
  //           // ),
  //           borderRadius: BorderRadius.circular(50),
  //         ),
  //         child: Center(
  //           child: Row(
  //             spacing: 5,
  //             children: [
  //               // SvgPicture.asset(
  //               //   'assets/svg/project.svg',
  //               //   width: 15,
  //               //   height: 15,
  //               //   color: Color(0xff4B59D9),
  //               // ),
  //               Text(
  //                 projectName,
  //                 textAlign: TextAlign.center,
  //                 style: GoogleFonts.poppins(
  //                   fontSize: 11,
  //                   fontWeight: FontWeight.w600,
  //                   color: baseColor,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _projectNameWidget({
    required String projectName,
    Color? color,
    required Function(int) onProjectSelected,
    required VoidCallback onAddButtonPressed,
  }) {
    var baseColor = color ?? const Color(0xff4B59D9);

    return PopupMenuButton<int>(
      // 1. Menu Styling: Added a subtle color tint so it isn't pure white
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: baseColor.withValues(alpha: 0.1)),
      ),
      offset: const Offset(0, 45),

      onSelected: (value) {
        if (value == -1) {
          onAddButtonPressed();
        } else {
          onProjectSelected(value);
        }
      },
      itemBuilder: (context) => [
        ...controller.projects.map(
          (p) => PopupMenuItem(
            value: p.id,
            child: Row(
              spacing: 5,
              children: [
                Icon(
                  Icons.circle,
                  size: 16,
                  color: AppColors.colorFromHex(p.color) ?? Colors.black87,
                ),
                Text(
                  p.schemaName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.colorFromHex(p.color) ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Regular List Items
        const PopupMenuDivider(height: 1, color: Colors.white),

        // 2. The Action Button: Styled to look like an actual button
        PopupMenuItem(
          value: -1,
          // Reduce the default padding so our custom container fills the space better
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.1), // Button-like background
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Centered content
              children: [
                Icon(Icons.manage_history_rounded, color: baseColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Manage Projects',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: baseColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      // 3. YOUR EXACT ORIGINAL TRIGGER TILE (plus a tiny down arrow)
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 5,
                children: [
                  Text(
                    projectName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: baseColor,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: baseColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLoginButtonLabel() {
    if (controller.authType.value == AuthType.none) return "Continue";
    if (controller.authType.value == AuthType.passwordOnly) return "Login";
    // return loginController.isOfflineLogin.value ? "Offline Login" : "Login";
    if (controller.authType.value == AuthType.both) return "Get OTP";

    return "Login";
  }
}
