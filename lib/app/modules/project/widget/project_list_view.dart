import 'package:animate_do/animate_do.dart';
import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:axpert/app/data/enums/project_enums.dart';
import 'package:axpert/app/modules/project/widget/project_list_tile.dart';
import 'package:axpert/app/core/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectListView extends GetView<ProjectController> {
  const ProjectListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child:
            // controller.currentTileState.value ==
            //     ProjectAddingState.defaultState
            Obx(
              () => (controller.projects.isNotEmpty)
                  ? ListView.separated(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 25.w,
                        vertical: 25.h,
                      ),
                      shrinkWrap: true,
                      itemCount: controller.projects.length,
                      separatorBuilder: (context, index) => 15.verticalSpace,
                      itemBuilder: (context, index) {
                        var project = controller.projects.reversed
                            .toList()[index];

                        return ProjectListTile(
                          key: ValueKey(index),
                          index: index,
                          project: project,
                        );
                      },
                    )
                  : _emptyWidget(),
            ),
      ),
    );
  }

  Widget _emptyWidget() {
    return Center(
      child: Column(
        spacing: 20.h,
        mainAxisSize: MainAxisSize.min,
        children: [
          ShakeX(
            from: 10,
            infinite: true,
            duration: Duration(seconds: 2),
            child: Image.asset("assets/icons/empty_icon3.png", width: 40),
          ),
          Text(
            'No Projects Configured Yet',
            style: GoogleFonts.dmSans(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
