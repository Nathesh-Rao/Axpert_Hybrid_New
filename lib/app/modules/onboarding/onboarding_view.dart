import 'package:animate_do/animate_do.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:axpert/app/core/routes/app_routes.dart';
import 'package:axpert/app/core/theme/app_colors.dart';
import 'package:axpert/app/widgets/axi_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: AxpertLogo(),
              ),

              Expanded(
                child: Stack(
                  children: [
                    Align(
                      child: ShakeY(
                        infinite: true,
                        duration: Duration(seconds: 15),
                        child: Container(
                          width: 300.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.11),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 20.w,
                      bottom: 110.h,
                      child: ShakeY(
                        infinite: true,
                        duration: Duration(seconds: 5),
                        child: Image.asset(
                          "assets/images/built_on_axpert.png",
                          width: 115.w,
                        ),
                      ),
                    ),
                    Align(
                      child: ShakeY(
                        infinite: true,
                        duration: Duration(seconds: 10),
                        // delay: Duration(milliseconds: 500),
                        child: Image.asset(
                          "assets/images/robot_full.png",
                          width: 350.w,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.w),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          "Simple and",
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 10.w,
                      children: [
                        Text(
                          "Intuitive",
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.w600,
                            height: 0,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 15.w),
                          height: 26.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100.r),
                            color: Colors.white,
                          ),
                          child: Center(
                            child: Text(
                              "Our New AXI 11.4",
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 11.sp,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        // Text(
                        //   "Business Platform",
                        //   style: GoogleFonts.sourceSerif4(
                        //     fontSize: 40.sp,
                        //     fontWeight: FontWeight.w600,
                        //     height: 0,
                        //   ),
                        //   textAlign: TextAlign.center,
                        // ),
                        ShaderMask(
                          blendMode: BlendMode
                              .srcIn, // This ensures the gradient only applies to the text
                          shaderCallback: (bounds) =>
                              LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                // Using the Hex codes and percentages from your screenshot
                                stops: const [0.0, 0.40, 0.66],
                                colors: const [
                                  Color(0xFFFF6B2C), // Orange at 0%
                                  Color(0xFFFFB432), // Yellow at 40%
                                  Color(0xFF2AB77E), // Green at 66%
                                ],
                              ).createShader(
                                Rect.fromLTWH(
                                  0,
                                  0,
                                  bounds.width,
                                  bounds.height,
                                ),
                              ),
                          child: Text(
                            "Business Platform",
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w600,
                              height: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    10.verticalSpace,
                    Text(
                      "Choose from a list of ready to use packages or  build custom sollutions effortlessly.",
                      style: GoogleFonts.poppins(fontSize: 13.sp),
                    ),
                    25.verticalSpace,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          WebViewController.open(url: "https://axi-global.com");
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white, // Sets the text color
                          padding: EdgeInsets.symmetric(
                            vertical: 16.h,
                          ), // Adjust vertical height
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              16.r,
                            ), // Adjust corner roundness
                          ),
                        ),
                        child: Text(
                          'Im a New User',
                          style: GoogleFonts.poppins(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600, // SemiBold
                          ),
                        ),
                      ),
                    ),

                    20.verticalSpace, // Spacing between buttons
                    // --- Second Button: Outlined style ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.toNamed(Routes.PROJECT_CONFIG);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor:
                              Colors.transparent, // Makes the inside empty
                          shadowColor: Colors
                              .transparent, // Prevents any shadow artifacts
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            side: const BorderSide(
                              color: AppColors.primaryOrange,
                              width: 1.5, // Adjust border thickness if needed
                            ),
                          ),
                        ),
                        child: Text(
                          'Im an Existing User',
                          style: GoogleFonts.poppins(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600, // SemiBold
                          ),
                        ),
                      ),
                    ),
                    20.verticalSpace, // Spacing between buttons
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
