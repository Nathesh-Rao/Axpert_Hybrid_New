import 'dart:ui';

import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:axpert/app/data/enums/project_enums.dart';
import 'package:axpert/app/modules/project/widget/project_hero_default_widget.dart';
import 'package:axpert/app/modules/project/widget/project_hero_manual_widget.dart';
import 'package:axpert/app/modules/project/widget/project_hero_qr_widget.dart';

import '../../../core/common.dart';

class ProjectHeroTile extends GetView<ProjectController> {
  const ProjectHeroTile({super.key});

  static const _duration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    // return Obx(() {
    //   final state = controller.currentTileState.value;
    //   return AnimatedSize(
    //     duration: _duration,
    //     curve: Curves.easeOutCubic,
    //     alignment: Alignment.topCenter,
    //     child: Container(
    //       width: double.infinity,
    //       constraints: _getConstraints(state),
    //       margin: EdgeInsets.all(25.w),
    //       // 1. Shadow opacity reduced so it doesn't muddy the background image
    //       decoration: BoxDecoration(
    //         borderRadius: BorderRadius.circular(16),
    //         boxShadow: [
    //           BoxShadow(
    //             color: Colors.black.withValues(
    //               alpha: 0.04,
    //             ), // Lowered from 0.08
    //             offset: const Offset(0, 8),
    //             blurRadius: 24,
    //             spreadRadius: -4,
    //           ),
    //         ],
    //       ),
    //       child: ClipRRect(
    //         borderRadius: BorderRadius.circular(16),
    //         child: BackdropFilter(
    //           // 2. Lowered blur from 16 to 10 so the image shapes are actually visible
    //           filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
    //           child: Container(
    //             decoration: BoxDecoration(
    //               // 3. Made the white gradient MUCH more transparent
    //               gradient: LinearGradient(
    //                 begin: Alignment.topLeft,
    //                 end: Alignment.bottomRight,
    //                 colors: [
    //                   Colors.white.withValues(alpha: 0.25), // Dropped from 0.6
    //                   Colors.white.withValues(alpha: 0.05), // Dropped from 0.2
    //                 ],
    //               ),
    //               border: Border.all(
    //                 color: Colors.white.withValues(
    //                   alpha: 0.6,
    //                 ), // Slightly softer rim
    //                 width: 1.2,
    //               ),
    //               borderRadius: BorderRadius.circular(16),
    //             ),
    //             child: ClipRect(
    //               child: SingleChildScrollView(
    //                 physics: const NeverScrollableScrollPhysics(),
    //                 child: AnimatedSwitcher(
    //                   duration: _duration,
    //                   switchInCurve: Curves.easeOut,
    //                   switchOutCurve: Curves.easeIn,
    //                   layoutBuilder: (currentChild, previousChildren) => Stack(
    //                     alignment: Alignment.topCenter,
    //                     children: [...previousChildren, ?currentChild],
    //                   ),
    //                   transitionBuilder: (child, animation) => FadeTransition(
    //                     opacity: animation,
    //                     child: SlideTransition(
    //                       position: Tween<Offset>(
    //                         begin: const Offset(0, 0.04),
    //                         end: Offset.zero,
    //                       ).animate(animation),
    //                       child: child,
    //                     ),
    //                   ),
    //                   child: KeyedSubtree(
    //                     key: ValueKey(state),
    //                     child: _getWidgetForState(state),
    //                   ),
    //                 ),
    //               ),
    //             ),
    //           ),
    //         ),
    //       ),
    //     ),
    //   );
    // });

    return Obx(() {
      final state = controller.currentTileState.value;
      return AnimatedSize(
        duration: _duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          constraints: _getConstraints(state),
          margin: EdgeInsets.all(25.w),
          // 1. The outer decoration handles the shadow to lift the glass off the white background
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              16,
            ), // Slightly rounder corners look better for glass
            boxShadow: [
              BoxShadow(
                color: AppColors.lightAccent,
                offset: const Offset(2, 2),
                blurRadius: 8,
                spreadRadius: 8,
              ),
            ],
          ),
          // 2. ClipRRect keeps the blur strictly inside the borders
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 16.0,
                sigmaY: 16.0,
              ), // The frost effect
              child: Container(
                decoration: BoxDecoration(
                  // 3. Semi-transparent gradient for the glass sheen
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 1),
                      Colors.white.withValues(alpha: 1),
                    ],
                  ),
                  // 4. A semi-transparent white border acts as the "rim" of the glass
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRect(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: AnimatedSwitcher(
                      duration: _duration,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previousChildren, ?currentChild],
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(state),
                        child: _getWidgetForState(state),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _getWidgetForState(ProjectAddingState state) {
    switch (state) {
      case ProjectAddingState.defaultState:
        return const ProjectHeroDefaultWidget();
      case ProjectAddingState.qrScan:
        return SizedBox(
          height: controller.qrTileHeight,
          child: const ProjectHeroQrWidget(),
        );
      case ProjectAddingState.urlDetails:
      case ProjectAddingState.accessCode:
      case ProjectAddingState.urlEdit:
        return const ProjectHeroManualWidget();
    }
  }

  BoxConstraints? _getConstraints(ProjectAddingState state) {
    switch (state) {
      case ProjectAddingState.defaultState:
        return BoxConstraints(
          minHeight: controller.defaultTileHeight,
          maxHeight: controller.defaultTileHeight,
        );
      case ProjectAddingState.qrScan:
      case ProjectAddingState.urlDetails:
      case ProjectAddingState.accessCode:
      case ProjectAddingState.urlEdit:
        return null;
    }
  }
}
