import 'package:axpert/app/modules/project/controller/project_controller.dart';
import 'package:get/get.dart';

class ProjectBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ProjectController());
  }
}
