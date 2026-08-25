import '../../../core/common.dart';

class SplashController extends GetxController {
  void onSplashLoad() {
    Future.delayed(Duration(seconds: 2), () {
      Get.offAllNamed(Routes.PROJECT_CONFIG);
    });
  }
}
