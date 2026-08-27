import 'package:axpert/app/data/services/storage_service.dart';

import '../../../core/common.dart';

class SplashController extends GetxController {
  void onSplashLoad() async {
    var lastsavedProject = await StorageService.getLastSelectedProject();

    if (lastsavedProject == null) {
      Get.offAllNamed(Routes.PROJECT_CONFIG);
    } else {
      Get.offAllNamed(Routes.LOGIN);
    }
  }
}
