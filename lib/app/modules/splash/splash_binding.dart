// TODO Implement this library.
import 'package:axpert/app/modules/splash/controller/splash_controller.dart';
import 'package:axpert/app/modules/webview/controller/webview_controller.dart';
import 'package:get/get.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SplashController());
    Get.put(WebViewController(), permanent: true);
  }
}
