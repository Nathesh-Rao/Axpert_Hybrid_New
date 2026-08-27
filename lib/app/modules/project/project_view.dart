import 'package:animate_do/animate_do.dart';
import 'package:axpert/app/core/tags/hero_tags.dart';
import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:axpert/app/data/enums/project_enums.dart';
import 'package:axpert/app/modules/project/widget/project_hero_tile.dart';
import 'package:axpert/app/modules/project/widget/project_list_tile.dart';
import 'package:axpert/app/modules/project/widget/project_list_view.dart';
import 'package:axpert/app/core/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/widgets.dart';

class ProjectView extends GetView<ProjectController> {
  const ProjectView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.fetchProjects();
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (controller.currentTileState.value ==
            ProjectAddingState.defaultState) {
          await controller.showExitConfirmationSheet();
        } else {
          controller.currentTileState.value = ProjectAddingState.defaultState;
        }
      },
      child: AppScaffold(
        // resizeToAvoidBottomInset: false,
        // bgIMage: "assets/images/login_bg2.png",
        body: SafeArea(
          child: Column(
            children: [
              AppBar(
                toolbarHeight: 90,
                centerTitle: true,
                automaticallyImplyLeading: false,
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: Obx(
                  () => FlipInX(
                    key: ValueKey(controller.currentTileState.value),
                    duration: Duration(milliseconds: 400),
                    child:
                        controller.currentTileState.value !=
                            ProjectAddingState.defaultState
                        ? IconButton(
                            // splashColor: color,
                            highlightColor: Colors.black.withValues(alpha: 0.2),
                            onPressed: controller.onTileCloseClick,
                            icon: CircleAvatar(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.05,
                              ),
                              radius: 15.r,
                              child: Icon(
                                CupertinoIcons.clear_circled_solid,
                                color: Colors.black,
                                size: 18.w,
                              ),
                            ),
                          )
                        : Hero(
                            tag: AppHeroTags.splashLogo,
                            child: AxpertLogo(),
                          ),
                  ),
                ),
                actions: [
                  // Obx(
                  //   () =>
                  //       controller.currentTileState.value !=
                  //           ProjectAddingState.defaultState
                  //       ? FadeIn(
                  //           key: ValueKey(controller.currentTileState.value),
                  //           duration: Duration(milliseconds: 400),
                  //           child: IconButton(
                  //             // splashColor: color,
                  //             highlightColor: Colors.black.withValues(alpha: 0.2),
                  //             onPressed: controller.onTileCloseClick,
                  //             icon: CircleAvatar(
                  //               backgroundColor: Colors.black.withValues(
                  //                 alpha: 0.05,
                  //               ),
                  //               radius: 15.r,
                  //               child: Icon(
                  //                 CupertinoIcons.clear_circled_solid,
                  //                 color: Colors.black,
                  //                 size: 18.w,
                  //               ),
                  //             ),
                  //           ),
                  //         )
                  //       : SizedBox.shrink(),
                  // ),
                  15.horizontalSpace,
                ],
              ),

              ProjectHeroTile(),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 25.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Connected apps",
                      style: GoogleFonts.dmSans(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Obx(() {
                      var projectsLength = controller.projects.length;
                      var bColor = projectsLength == 0
                          ? AppColors.primaryPink
                          : AppColors.primaryGreen;
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 2.h,
                        ),
                        height: 26.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100.r),
                          color: bColor.withValues(alpha: 0.14),
                          border: Border.all(color: bColor),
                        ),
                        child: Center(
                          child: Text(
                            "$projectsLength active",
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: bColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              ProjectListView(),
            ],
          ),
        ),
        bottomNavigationBar: Obx(() {
          var canShow =
              ((controller.currentTileState.value ==
                  ProjectAddingState.defaultState) &&
              controller.projects.length <= 3);
          if (canShow) {
            return AxpertInfoWidget(
              padding: EdgeInsetsGeometry.only(top: 5, bottom: 10),
            );
          } else {
            return SizedBox.shrink();
          }
        }),
      ),
    );
  }
}
