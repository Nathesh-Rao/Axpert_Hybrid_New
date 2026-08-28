import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:get/get.dart';

class WebviewBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(WebViewController());
  }
}
