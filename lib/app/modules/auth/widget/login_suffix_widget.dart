import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/modules/auth/controller/auth_controller.dart';
import 'package:flutter/material.dart';

class WidgetRotatingSuffixField extends GetView<AuthController> {
  const WidgetRotatingSuffixField({super.key, this.width = 20});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Spin(
        infinite: true,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            "assets/images/loading_circle.png",
            width: width,
            color: controller.selectedColor.value,
          ),
        ), // or Image.network
      ),
    );
  }
}
