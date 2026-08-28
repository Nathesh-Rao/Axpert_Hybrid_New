import 'package:axpert/app/data/services/storage_service.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/common.dart';

class SplashController extends GetxController {

  
  void onSplashLoad() async {
    await checkIfDeviceSupportBiometric();
    await checkAndNavigate();
  }

  Future<void> checkIfDeviceSupportBiometric() async {
    final LocalAuthentication auth = LocalAuthentication();
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool canAuthenticate =
        canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    // LogService.writeOnConsole(message: "canAuthenticate: $canAuthenticate");
    // LogService.writeLog(message: "[i] SplashPage\nScope:checkIfDeviceSupportBiometric()\nCanAuthenticate: $canAuthenticate");
    if (canAuthenticate) {
      final List<BiometricType> availableBiometrics = await auth
          .getAvailableBiometrics();
      // LogService.writeOnConsole(message: "List: $availableBiometrics");
      // LogService.writeLog(
      //     message: "[i] SplashPage\nScope:checkIfDeviceSupportBiometric()\nAvailable Biometrics: $availableBiometrics");

      // if (availableBiometrics.contains (BiometricType.fingerprint) ||
      //     availableBiometrics.contains(BiometricType.weak) ||
      //     availableBiometrics.contains(BiometricType.strong))
      // if (availableBiometrics.isNotEmpty) {
      //   AppStorage().storeValue(AppStorage.CAN_AUTHENTICATE, canAuthenticate);
      // } else {
      //   AppStorage().remove(AppStorage.CAN_AUTHENTICATE);
      // }

      await StorageService.setCanAuthenticate(availableBiometrics.isNotEmpty);
    }
  }

  Future<void> checkAndNavigate() async {
    var lastsavedProject = await StorageService.getLastSelectedProject();
    if (lastsavedProject == null) {
      Get.offAllNamed(Routes.PROJECT_CONFIG);
    } else {
      Get.offAllNamed(Routes.LOGIN);
    }
  }
}
