import 'dart:async';
import 'package:axpert/app/core/common.dart';
import 'package:axpert/app/data/services/api_manger.dart';
import 'package:axpert/app/modules/auth/controller/auth_controller.dart';

class ForgetPasswordController extends GetxController {
  TextEditingController emailController = TextEditingController();
  TextEditingController userNameController = TextEditingController();
  TextEditingController otpController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  var errUserName = ''.obs;
  var showPass = false.obs;
  var showConPass = false.obs;
  var showOTP = false.obs;
  var OTPSent = false.obs;
  var emailError = ''.obs;
  var otpError = ''.obs;
  var passError = ''.obs;
  var conPassError = ''.obs;
  var otpHasError = true.obs;
  var enteredPin = ''.obs;
  var otpLength = ''.obs;

  var otpAttempts = ''.obs;
  var regID = ''.obs;
  int timerMaxSeconds = 60;
  int currentSeconds = 0;
  var timerText = '00:00'.obs;
  var showTimer = true.obs;
  var reSendOtpCount = 0;
  var projectName = '';

  var isFPasswordLoading = false.obs;
  // var userTypeList = <String>[].obs;
  // var ddSelectedValue = "Power".obs;

  // @override
  // onInit() {
  //   super.onInit();
  //   userNameController.text = StorageService.userName ?? "";
  // }

  // void fetchUserTypeList() async {
  //   LoadingScreen.show();
  //   final result = await ApiManager.instance.getUserGroups();
  //   LoadingScreen.dismiss();

  //   switch (result) {
  //     case ApiSuccess(:final data):
  //       userTypeList.clear();
  //       for (var group in data) {
  //         userTypeList.add(CommonMethods.capitalize(group));
  //       }
  //       userTypeList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  //       ddSelectedValue.value = userTypeList.contains("Power") ? "Power" : userTypeList.first;
  //       break;
  //     case ApiError(:final message):
  //       // Optionally handle error fetching groups
  //       print(message);
  //       break;
  //   }
  // }

  bool vaidateForm() {
    emailError.value = '';
    errUserName.value = '';

    if (userNameController.text.trim().isEmpty) {
      errUserName.value = "Enter User Name";
      return false;
    }
    if (emailController.text.trim().isEmpty) {
      emailError.value = "Please Enter Email ID";
      return false;
    }
    if (!emailController.text.trim().isEmail) {
      emailError.value = "Please Enter a valid Email ID";
      return false;
    }
    return true;
  }

  bool validateOTPSubmittionForm() {
    otpError.value = passError.value = conPassError.value = '';
    Pattern pattern =
        r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{7,}$';
    RegExp regex = RegExp(pattern.toString());

    if (otpController.text.isEmpty) {
      otpError.value = "Enter OTP";
      return false;
    }
    if (otpController.text.length.toString() != otpLength.value) {
      otpError.value = "Please Enter valid OTP";
      return false;
    }
    if (passwordController.text.trim().isEmpty) {
      passError.value = "Enter Password";
      return false;
    }
    if (!regex.hasMatch(passwordController.text)) {
      passError.value =
          "Password should contain upper, lower, digit and Special character";
      return false;
    }
    if (passwordController.text.length <= 7) {
      passError.value = "Password is Weak Must be more than 8 characters";
      return false;
    }
    if (confirmPasswordController.text.trim().isEmpty) {
      conPassError.value = "Enter Confirm password";
      return false;
    }
    if (confirmPasswordController.text != passwordController.text.trim()) {
      conPassError.value = "Password does not match";
      return false;
    }
    return true;
  }

  void proceedButtonClicked() async {
    if (vaidateForm()) {
      isFPasswordLoading.value = true;
      final result = await ApiManager.instance.requestForgotPasswordOTP(
        appName: projectName,
        username: userNameController.text.trim(),
        email: emailController.text.trim(),
      );
      isFPasswordLoading.value = false;

      switch (result) {
        case ApiSuccess():
          Get.defaultDialog(
            title: "Success",
            middleText: "  Password is reset and sent to your email  ",
            confirm: ElevatedButton(
              onPressed: () {
                if (Get.isRegistered<AuthController>()) {
                  Get.find<AuthController>().userPasswordController.clear();
                }
                Get.close(2);
              },
              child: const Text("OK"),
            ),
          );

          break;

        case ApiError(:final message):
          Get.snackbar(
            "Alert!",
            message,
            snackPosition: SnackPosition.BOTTOM,
            colorText: Colors.white,
            backgroundColor: Colors.red,
          );
          break;
      }
    }
  }

  void startTimer() {
    showTimer.value = true;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      currentSeconds = timer.tick;
      timerText.value =
          '${(((timerMaxSeconds - currentSeconds) ~/ 60) % 60).toString().padLeft(2, '0')}: ${((timerMaxSeconds - currentSeconds) % 60).toString().padLeft(2, '0')}';

      if (timer.tick >= timerMaxSeconds) {
        showTimer.value = false;
        timer.cancel();
      }
    });
  }

  void verifyOtp() async {
    isFPasswordLoading.value = true;
    final result = await ApiManager.instance.validateUserOTP(
      regId: regID.value,
      otp: enteredPin.value,
    );
    isFPasswordLoading.value = false;

    switch (result) {
      case ApiSuccess():
        // Handle success logic if needed
        break;
      case ApiError(:final message):
        otpError.value = message;
        break;
    }
    reSendOtpCount++;
  }

  void reSendOTP() {
    try {
      if (reSendOtpCount < (int.tryParse(otpAttempts.value) ?? 0)) {
        proceedButtonClicked();
        reSendOtpCount++;
        otpError.value = "";
      } else {
        otpError.value =
            "You exceeded the maximum limit.\nPlease try again later";
      }
    } catch (e) {
      otpError.value =
          "You exceeded the maximum limit.\nPlease try again later";
    }
  }

  void submitOTPClicked() async {
    if (validateOTPSubmittionForm()) {
      isFPasswordLoading.value = true;
      final result = await ApiManager.instance.resetPasswordWithOTP(
        appName: projectName,
        email: emailController.text.trim(),
        regId: regID.value,
        updatedPassword: passwordController.text.trim(),
        otp: otpController.text.trim(),
      );
      isFPasswordLoading.value = false;

      switch (result) {
        case ApiSuccess(:final data):
          Get.defaultDialog(
            title: "Success",
            middleText: data,
            confirm: ElevatedButton(
              onPressed: () {
                Get.back(); // close dialog
                Get.back(); // close forget password screen
              },
              child: const Text("Ok"),
            ),
          );
          break;

        case ApiError(:final message):
          Get.snackbar(
            "Alert!",
            message,
            snackPosition: SnackPosition.BOTTOM,
            colorText: Colors.white,
            backgroundColor: Colors.red,
          );
          break;
      }
    }
  }
}
