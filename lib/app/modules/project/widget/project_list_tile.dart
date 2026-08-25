import 'dart:developer';

import 'package:axpert/app/data/models/project_model.dart';
import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:axpert/app/core/theme/app_colors.dart';
import 'package:axpert/app/core/utils/haptic_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectListTile extends GetView<ProjectController> {
  const ProjectListTile({
    super.key,
    required this.index,
    required this.project,
  });
  final int index;
  final ProjectModel project;
  @override
  Widget build(BuildContext context) {
    // final ProjectModel project = 

    return Obx(() {
      final isEditing = controller.editingProject.value?.id == project.id;
      final fallbackColor = AppColors.getItemColor(index);
      final accentColor =
          AppColors.colorFromHex(project.color) ?? fallbackColor;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          // 1. Light theme background: Pure white when idle, soft tint when editing
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // 2. Light theme borders: Soft grey when idle, accent color when editing
          border: Border.all(
            color: isEditing
                ? accentColor.withValues(alpha: 0.4)
                : Colors.grey.shade200,
            width: isEditing ? 1.2 : 1,
          ),
          // 3. Subtle shadow to make the list items pop off the white scaffold
          boxShadow: [
            if (!isEditing)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Edit banner ──────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isEditing
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical:
                              10.h, // Slightly more padding for breathing room
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          border: Border(
                            bottom: BorderSide(
                              color: accentColor.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_square,
                              color: accentColor,
                              size: 14.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Editing this project',
                              style: GoogleFonts.dmSans(
                                color: accentColor,
                                fontSize: 12.sp,
                                fontWeight:
                                    FontWeight.w600, // Bolder for clarity
                              ),
                            ),
                            const Spacer(),
                            // Cancel edit
                            GestureDetector(
                              onTap: () {
                                HapticManager.light();
                                controller.cancelEdit();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.black54),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      color: Colors
                                          .black54, // Better contrast in light mode
                                      size: 14.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'Cancel',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.black87,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Tile ─────────────────────────────────────────
            ListTile(
              onTap: () {
                controller.onProjectTileClick(project);
              },
              tileColor: Colors.transparent,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 8.h,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              leading: ClipOval(
                child: SizedBox(
                  width: 48.r,
                  height: 48.r,
                  child: Container(
                    color: accentColor.withValues(alpha: 0.08),
                    padding: EdgeInsets.all(5),
                    child: Image.network(
                      project.logourl,
                      fit: BoxFit.contain,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                            return child;
                          },
                      errorBuilder: (_, _, _) {
                        log(project.logourl, name: "ProjectTile");
                        return Center(
                          child: Image.asset(
                            'assets/icons/project_icon.png',
                            width: 24.w,
                            color: accentColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              title: Text(
                project.caption.isNotEmpty
                    ? project.caption
                    : project.schemaName,
                style: GoogleFonts.poppins(
                  color: Colors.black87, // Dark text for white background
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(
                  project.url,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: Colors.grey.shade500, // Medium grey for URL
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionButton(
                    onPressed: isEditing
                        ? null
                        : () {
                            HapticManager.light();
                            controller.onEditProjectClick(project);
                          },
                    icon: Icons.edit_square,
                    color: accentColor,
                  ),
                  SizedBox(width: 4.w),
                  _actionButton(
                    onPressed: isEditing
                        ? null
                        : () {
                            if (project.id != null) {
                              HapticManager.warning();
                              _showAndDeleteProject(project);
                            }
                          },
                    icon: CupertinoIcons.clear_circled_solid,
                    color: AppColors.accentRed,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Action Button Helper ────────────────────────────────────────
  IconButton _actionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color color,
  }) {
    return IconButton(
      highlightColor: color.withValues(alpha: 0.1),
      splashColor: color.withValues(alpha: 0.1),
      onPressed: onPressed,
      icon: CircleAvatar(
        backgroundColor: color.withValues(
          alpha: 0.08,
        ), // Soft background for the button
        radius: 16.r,
        child: Icon(
          icon,
          // If disabled (editing), make it very light grey. Otherwise, use the assigned color.
          color: onPressed == null ? Colors.grey.shade300 : color,
          size: 18.w,
        ),
      ),
    );
  }

  // ── Delete Dialog (Light Theme) ─────────────────────────────────
  void _showAndDeleteProject(ProjectModel project) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white, // Crisp white background
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            24,
          ), // Slightly rounder for a modern feel
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.accentRed,
                  size: 32,
                ),
              ),
              20.verticalSpace,
              Text(
                'Remove Project',
                style: GoogleFonts.poppins(
                  color: Colors.black87, // Dark title
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              12.verticalSpace,
              Text(
                'Remove "${project.caption.isNotEmpty ? project.caption : project.schemaName}" from your connected apps?',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: Colors.grey.shade600, // Softer grey for body text
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              32.verticalSpace,
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 52.h,
                      child: OutlinedButton(
                        onPressed: Get.back,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87, // Dark text on press
                          side: BorderSide(
                            color: Colors.grey.shade300, // Light grey border
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(
                            color: Colors.black87,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  12.horizontalSpace,
                  // Remove Button
                  Expanded(
                    child: SizedBox(
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          controller.deleteProject(project.id!);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Remove',
                          style: GoogleFonts.dmSans(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
