import 'dart:developer';

import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:local_auth/local_auth.dart';

class CommonMethods {
  static Future<bool> showBiometricDialogOld() async {
    try {
      final auth = LocalAuthentication();

      final types = await auth.getAvailableBiometrics();
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;

      log(types.toString(), name: "showBiometricDialog types");
      log(supported.toString(), name: "showBiometricDialog supported");
      log(canCheck.toString(), name: "showBiometricDialog canCheck");
      final isAuthenticated = await auth.authenticate(
        localizedReason: "Please use your Biometric to login",
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric authentication required!',
            cancelButton: 'No thanks',
          ),
          IOSAuthMessages(cancelButton: 'No thanks'),
        ],

        biometricOnly: false,
        // useErrorDialogs: false,
        // stickyAuth: false,
        persistAcrossBackgrounding: true,
      );

      return isAuthenticated;
    } catch (e) {
      print("showBiometricDialog error => $e");
      return false;
    }
  }

static  Future<bool> showBiometricDialog() async {
    var tag = "showBiometricDialog";
    final auth = LocalAuthentication();

    try {
      final bool supported = await auth.isDeviceSupported();
      final bool canCheck = await auth.canCheckBiometrics;
      final List<BiometricType> biometrics = await auth
          .getAvailableBiometrics();

      log('isDeviceSupported: $supported', name: tag);
      log('canCheckBiometrics: $canCheck', name: tag);
      log('availableBiometrics: $biometrics', name: tag);

      if (!supported || !canCheck) {
        return false;
      }

      final bool isAuthenticated = await auth.authenticate(
        localizedReason: 'Please use biometrics to login',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric authentication required!',
            cancelButton: 'No thanks',
          ),
          IOSAuthMessages(cancelButton: 'No thanks'),
        ],
        // options: const AuthenticationOptions(
        //   biometricOnly: true,
        //   stickyAuth: true,
        // ),
        biometricOnly: true,
      );

      log('isAuthenticated: $isAuthenticated', name: tag);

      return isAuthenticated;
    } on LocalAuthException catch (e) {
      log('LOCAL AUTH ERROR CODE: ${e.code}', name: tag);
      log('LOCAL AUTH ERROR: $e', name: tag);
      return false;
    } catch (e, stackTrace) {
      log('BIOMETRIC ERROR: $e', name: tag);
      log('STACKTRACE: $stackTrace', name: tag);
      return false;
    }
  }
}
