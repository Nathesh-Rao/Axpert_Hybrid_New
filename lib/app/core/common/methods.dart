import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:local_auth/local_auth.dart';

class CommonMethods {
  static Future<bool> showBiometricDialog() async {
    try {
      final auth = LocalAuthentication();

      final isAuthenticated = await auth.authenticate(
        localizedReason: "Please use your Biometric to login",
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric authentication required!',
            cancelButton: 'No thanks',
          ),
          IOSAuthMessages(cancelButton: 'No thanks'),
        ],

        biometricOnly: true,
        // useErrorDialogs: false,
        // stickyAuth: false,
      );

      return isAuthenticated;
    } catch (e) {
      print("getBiometricStatus error => $e");
      return false;
    }
  }
}
