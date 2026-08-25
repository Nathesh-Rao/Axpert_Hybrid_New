import 'package:animate_do/animate_do.dart';
import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:axpert/app/core/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectHeroManualWidget extends GetView<ProjectController> {
  const ProjectHeroManualWidget({super.key});

  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── TabBar (Modern Segmented Control Style) ────────
        Padding(
          padding: EdgeInsets.all(6.w),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100, // Soft grey background
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TabBar(
              controller: controller.manualTabCtrl,
              padding: EdgeInsets.all(4.w),
              dividerColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white, // White pill indicator
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black87, // Dark text for active
              unselectedLabelColor:
                  Colors.grey.shade600, // Muted text for inactive
              labelStyle: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Obx(
                  () => Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(active: controller.manualTabIndex.value == 0),
                        SizedBox(width: 7.w),
                        const Text('URL Details'),
                      ],
                    ),
                  ),
                ),
                Obx(
                  () => Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(active: controller.manualTabIndex.value == 1),
                        SizedBox(width: 7.w),
                        const Text('Access code'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Content ────────────────────────────────────────
        Obx(() {
          final index = controller.manualTabIndex.value;
          return AnimatedSwitcher(
            duration: _duration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: [...previousChildren, ?currentChild],
            ),
            child: KeyedSubtree(
              key: ValueKey(index),
              child: index == 0
                  ? const _UrlDetailsTab()
                  : const _AccessCodeTab(),
            ),
          );
        }),
      ],
    );
  }

  Widget _dot({required bool active}) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active
          ? AppColors
                .buttonBackground // Use your primary brand color for the active dot
          : Colors.grey.shade400,
    ),
  );
}

// ────────────────────────────────────────────────────────────────────
// URL Details tab content
// ────────────────────────────────────────────────────────────────────
class _UrlDetailsTab extends GetView<ProjectController> {
  const _UrlDetailsTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 14.h),
      child: Form(
        key: controller.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InputField(
              fieldKey: controller.fieldKeys['webUrl'],
              focusNode: controller.webUrlFocusNode,
              controller: controller.webUrlCtrl,
              hint: 'Web URL',
              keyboardType: TextInputType.url,
              validator: controller.validateUrl,
              onFieldSubmitted: (_) {
                controller.validateField(controller.fieldKeys['webUrl']);
              },
            ),
            SizedBox(height: 10.h),
            _InputField(
              fieldKey: controller.fieldKeys['armUrl'],

              focusNode: controller.armUrlFocusNode,
              controller: controller.armUrlCtrl,
              hint: 'ARM URL',
              keyboardType: TextInputType.url,
              validator: controller.validateUrl,
              onFieldSubmitted: (_) {
                controller.validateField(controller.fieldKeys['armUrl']);
              },
            ),
            SizedBox(height: 10.h),
            _InputField(
              fieldKey: controller.fieldKeys['connectionName'],
              focusNode: controller.connectionNameFocusNode,
              controller: controller.connectionNameCtrl,
              hint: 'Connection Name',
              validator: controller.validateNormalField,
              onFieldSubmitted: (_) {
                controller.validateField(
                  controller.fieldKeys['connectionName'],
                );
              },
            ),
            SizedBox(height: 10.h),
            _InputField(
              fieldKey: controller.fieldKeys['connectionCaption'],
              focusNode: controller.connectionCaptionFocusNode,
              controller: controller.connectionCaptionCtrl,
              hint: 'Connection Caption',
              validator: controller.validateNormalField,
              onFieldSubmitted: (_) {
                controller.validateField(
                  controller.fieldKeys['connectionCaption'],
                );
              },
            ),
            SizedBox(height: 14.h),
            _SaveButton(onTap: controller.onSaveUrlDetails),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Access Code tab content
// ────────────────────────────────────────────────────────────────────
class _AccessCodeTab extends GetView<ProjectController> {
  const _AccessCodeTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 14.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.primaryOrange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.key_rounded,
                  color: AppColors.primaryOrange,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Enter the access code shared by your workspace admin',
                    style: GoogleFonts.dmSans(
                      color:
                          Colors.black87, // Changed for light mode readability
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          _InputField(
            controller: controller.accessCodeCtrl,
            hint: 'Connection code',
          ),
          SizedBox(height: 14.h),
          Obx(
            () => SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: controller.isAccessCodeLoading.value
                    ? null
                    : controller.onSaveAccessCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonBackground,
                  foregroundColor: Colors
                      .white, // Ensure text/loader is white on colored button
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: controller.isAccessCodeLoading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Save Project',
                        style: GoogleFonts.dmSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final Key? fieldKey;
  final void Function(String)? onFieldSubmitted;
  const _InputField({
    this.fieldKey,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.focusNode,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    var bStyle = GoogleFonts.dmSans(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
    );

    return TextFormField(
      focusNode: focusNode,
      controller: controller,
      keyboardType: keyboardType,

      style: bStyle.copyWith(color: AppColors.textOnLight),
      // 1. Cursor matches the primary theme color
      cursorColor: AppColors.lightPrimary,
      decoration: InputDecoration(
        prefixText: hint.toLowerCase().contains("url") ? "https://" : null,
        prefixStyle: bStyle.copyWith(color: AppColors.lightPrimary),
        // hintText: hint,
        labelText: hint,
        labelStyle: bStyle.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: bStyle.copyWith(
          color: AppColors.lightPrimary,
          fontWeight: FontWeight.bold,
        ),
        hintStyle: GoogleFonts.dmSans(
          color: Colors
              .grey
              .shade400, // Slightly lighter hint so text pops more when typed
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        // 2. A very soft, cool-toned grey that looks premium on white
        fillColor: AppColors.lightAccent.withAlpha(50),

        // 3. Idle state: NO BORDER. This makes the UI look significantly cleaner.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(
            color: AppColors.lightPrimary,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),

          borderSide: BorderSide.none,
        ),

        // 4. Focused state: The primary border appears only when they are typing
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(
            color: AppColors.lightPrimary,
            width: 1.5,
          ),
        ),

        // errorBorder: OutlineInputBorder(
        //   borderRadius: BorderRadius.circular(8.r),
        //   borderSide: const BorderSide(color: AppColors.accentRed, width: 1.5),
        // ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Save Button
// ────────────────────────────────────────────────────────────────────
class _SaveButton extends GetView<ProjectController> {
  final VoidCallback? onTap;
  const _SaveButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: Obx(
        () => ElevatedButton(
          onPressed: controller.isProjectSaving.value ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonBackground,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.backgroundDarkStart,
            disabledForegroundColor: AppColors.white,

            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          child: FadeIn(
            child: controller.isProjectSaving.value
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      CupertinoActivityIndicator(color: AppColors.white),
                      Text(
                        controller.projectSavingInfoText.value,
                        style: GoogleFonts.dmSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    controller.editingProject.value != null
                        ? 'Update Project'
                        : 'Save Project',
                    style: GoogleFonts.dmSans(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
