import 'package:axpert/app/modules/splash/controller/splash_controller.dart';
import 'package:get/get.dart';

import '../../controller/global_controller.dart';
import '../../data/services/connectivity/internet_connectivity.dart';
import '../offline_form_pages/controller/offline_form_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SplashController());
    Get.put(GlobalVariableController(), permanent: true);
    Get.put(InternetConnectivity(), permanent: true);
    Get.put(OfflineFormController(), permanent: true);
  }
}
