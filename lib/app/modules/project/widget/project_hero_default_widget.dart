import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:axpert/app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/state_manager.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectHeroDefaultWidget extends GetView<ProjectController> {
  const ProjectHeroDefaultWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset("assets/icons/project_hero_icon2.png", width: 168.w),
        12.verticalSpace,
        Text(
          "Add a new connection",
          style: GoogleFonts.dmSans(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnLight,
            letterSpacing: -0.8.sp,
          ),
        ),
        8.verticalSpace,
        Text(
          "Link your application via qr code \nor add urls manually",
          style: GoogleFonts.poppins(
            fontSize: 11.sp,
            letterSpacing: -0.8.sp,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        16.verticalSpace,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 25.w),

          child: Row(
            spacing: 15.w,
            children: [
              // ── Scan QR ──────────────────────────────
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: controller.onScanQRClick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button1,
                    foregroundColor: AppColors.textWhite,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.qr_code_scanner_rounded, size: 20.w),
                  label: Text(
                    'Scan QR',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // ── Add Manually ─────────────────────────
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: controller.onAddManuallyClick,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppColors.button1,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: AppColors.button1,
                        width: 1,
                      ),
                    ),
                  ),
                  icon: Text(
                    '://',
                    style: GoogleFonts.poppins(
                      color: AppColors.button1,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  label: Text(
                    'add manually',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        8.verticalSpace,
      ],
    );
  }
}
